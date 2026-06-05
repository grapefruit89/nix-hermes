---
title: "Storage Domain Guide: Hybrid Pooling, Spindown, & Pending Watcher"
domain: 30
folder: 30-storage
status: active
complexity: 4
last_reviewed: 2026-05-26
links:
  adr:     ADR-30-storage.md
  modules:
    - path: Nix Files/modules/30-storage.nix
---

# Storage Domain Guide: Hybrid Pooling, Spindown, & Pending Watcher

> **Operational guide for managing the hybrid storage pool (SSD + ext4 MergerFS), diagnosing mechanical HDD spindown states, integrating unlabelled hot-plugged drives via the Pending Disks Watcher, and verifying encrypted offsite Restic backups.**
> Ensures maximum data integrity, predictable recovery, and high energy efficiency.

---

## Prerequisites

Before modifying filesystems, adding drives, or restoring backups, verify:
- [x] Host has `ext4` and `btrfs` filesystem support active.
- [x] Ephemeral root (`tmpfs`) is active, with `/persist` mapped to the persistent SSD cache drive (Tier A).
- [x] The `media` group exists with GID 169 (NixOS-declared).

---

## How It Works

```
                        [Client Writes / Downloads]
                                     │
                                     ▼ (category.create=ff)
                             [Tier B: SSD Cache]
                                     │
                        (Same-Disk Staging in .staging/)
                                     │
                                     ▼ (rsync atomic metadata move)
                             [Tier C: ext4 JBOD] ◄─── (Spun down 99% of time)
                                     ▲
                                     │ (Virtual pooling)
[Jellyfin / Media Stack] ◄─── [MergerFS: /mnt/media] ◄─── [SSD: Irreplaceable State]
```

1. **Hybrid Virtualization:** MergerFS pools ext4 drives (Tier C) under `/mnt/media`, virtualized alongside local SSD storage (Tier A). Jellyfin and other apps interact with `/mnt/media` and SSD state directories seamlessly.
2. **First Found Write:** New files are written exclusively to the SSD Cache (Tier B) to prevent mechanical HDD spin-ups.
3. **Pending Watcher:** Unformatted connected drives are flagged by `nixhome-pending-watcher` and stored as `.pending` files to block silent raw writes.
4. **State Protection:** Crucial databases (PostgreSQL, Vaultwarden, age keys) are backed up securely using locally encrypted Restic offsite S3 uploads.

---

## Operational Procedures

### Resolving & Formatting a Pending Disk

If a newly plugged disk is flagged by the `nixhome-pending-watcher` timer, you will find a `.pending` file under `/run/nixhome-pending-disks/`. To register and format the disk for Tier C:

```bash
# 1. List active pending drives
cat /run/nixhome-pending-disks/*.pending

# 2. Parted format the raw disk (e.g. /dev/sdb)
# Enforce GPT partition table and primary ext4 filesystem
parted -s /dev/sdb mklabel gpt mkpart primary ext4 0% 100%

# 3. Label the partition for Tier C mapping
e2label /dev/sdb1 DISK_STORAGE_3

# 4. Mount the drive under the MergerFS pool branch structure
# (Add the mount path /mnt/disk3 to your NixOS configuration branches)
mkdir -p /mnt/disk3
mount /dev/disk/by-label/DISK_STORAGE_3 /mnt/disk3
```

### Enforcing GID 169 Permissions

Ensure setgid is active across all branches to avoid permission conflicts between downstream tools:

```bash
# Apply ownership recursively
chown -R root:media /mnt/fast_pool/downloads
chown -R root:media /mnt/media

# Force Setgid inheritance
chmod -R 775 /mnt/fast_pool/downloads
chmod -R 775 /mnt/media
find /mnt/fast_pool/downloads -type d -exec chmod g+s {} +
find /mnt/media -type d -exec chmod g+s {} +
```

### Initializing & Verifying Restic Cloud Backups

```bash
# 1. Initialize the Restic S3 bucket (handled via decrypted SOPS secret environment)
restic init

# 2. Run a manual state backup to verify credentials and connection stability
restic backup /persist/var/lib/postgresql --tag "manual-test"

# 3. List all remote snapshots
restic snapshots

# 4. Verify backup timer and status
systemctl status restic-backups-tier-a-sovereign.service
```

### Diagnosing HDD Spindown States

To verify that MergerFS is successfully enabling `hd-idle` to spin down mechanical drives:

```bash
# 1. Query disk power status (Must NOT wake up the drive)
hdparm -C /dev/disk/by-label/DISK_STORAGE_*

# 2. Inspect active file locks on the pool (Finds files blocking spindown)
lsof /mnt/media

# 3. Verify dropcacheonclose is active in active mount parameters
mount | grep mergerfs
```

---

## Verification Commands

These commands must all exit with `PASS` status to confirm storage health:

```bash
# 1. Verify MergerFS pool is successfully mounted
mountpoint -q /mnt/media && echo "PASS: mergerfs active"

# 2. Verify pending watcher timer is running
systemctl is-active --quiet nixhome-pending-watcher.timer && echo "PASS: watcher timer active"

# 3. Verify persistent storage filesystem is healthy
df -h /persist && echo "PASS: persist storage active"
```

---

## Known Failure Modes

| Symptom | Likely Cause | Operational Fix |
|:---|:---|:---|
| HDDs never spin down | A service is writing temporary cache files directly to Tier C | Inspect active processes using `lsof /mnt/media`. Map transient folders (e.g. Jellyfin transcode cache) strictly to Tier B SSD or `/tmp`. |
| Pending disk watcher fails to run | /run path is full or lacks permissions | Clean up transient files under `/run` and verify systemd service unit parameters. |
| Restic backup fails with "repository locked" | A previous backup crashed or was interrupted | Run `restic unlock` using your decrypted repository credentials. |
| Permission Denied on downloads | Downloaded files were saved with `umask 022` | Force your Usenet downloader configuration (SABnzbd) to enforce `umask 002`. |

---

## NixOS-Native Wunschliste Gotchas: MergerFS & Database Locks

### Database Concurrency on Pooled Filesystems (MergerFS Pitfall)
* **The Gotcha (Database Corruption or Locked State):** Several services in our stack (e.g., Paperless-ngx, Vaultwarden, Home Assistant, n8n) rely on SQLite databases or transactional SQL engines. If you mount their state directories (`dataDir`) on a virtualized `mergerfs` pool, they will fail with `database is locked` or corrupt their schemas because MergerFS does not support the strict atomic POSIX file locking required by database engines.
* **The Resolution:** 
  1. **Strict Separation:** Always isolate transactional service data directories from bulk media. 
  2. Keep all databases on the native fast-tier SSD storage (Btrfs/Ext4 subvolumes on Tier A persistent cache: `/data/state/` or `/persist/var/lib/`).
  3. Map the `mergerfs` mount (`/mnt/media/`) exclusively for bulk, read-heavy documents, movies, and photos, which are unaffected by transactional lock restrictions.
* **Declarative Folder Integrity:** Ensure the `dataDir` directories (like `/data/state/postgresql-live` and `/var/lib/vaultwarden`) are explicitly whitelisted in `30-storage.nix` under `my.storage.impermanence.directories` so they survive boot rollbacks, keeping the data stored directly on Tier A fast storage.