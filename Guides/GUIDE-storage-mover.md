---
title: "Storage Guide: Same-Disk Staging & MergerFS Mount Tuning"
domain: 30
folder: 30-storage
status: active
complexity: 3
last_reviewed: 2026-05-26
links:
  adr:     ADR-30-storage.md
  modules:
    - path: Nix Files/modules/30-storage.nix
---

# Storage Guide: Same-Disk Staging & MergerFS Mount Tuning

> **Operational guide for configuring MergerFS SSD-to-HDD caching, enforcing Same-Disk Staging, establishing the smart-mover execution rules, and implementing the global GID 169 (media group) permissions standard.**
> This standard guarantees maximum HDD spindown (99% idle time) and eliminates permission drift between downloader and media application layers.

---

## Prerequisites

Before configuring storage pooling or scripts, verify:
- [x] Physical drive partitions are correctly labeled: `DISK_CACHE` (Tier B SSD) and `DISK_STORAGE_1` etc. (Tier C HDDs).
- [x] All mechanical disks are configured with `hdparm` or `hd-idle` to spin down after 15 minutes of inactivity.
- [x] The `media` group exists with GID 169 in `/etc/group` (NixOS declaration).

---

## How It Works

```
[Write Requests]
       │
       ▼ (category.create=ff)
[Tier B: SSD Cache (DISK_CACHE)] ◄─── (Fast Write, Minimal Power Draw)
       │
       ▼ (Same-Disk Staging in .staging/)
[Atomic Metadata Move]
       │
       ▼ (Smart-Mover triggered at 85% SSD capacity OR when HDDs are active/idle)
[Tier C: HDD Array (DISK_STORAGE_*)] ◄─── (Long-term Archives, Spun down 99% of time)
```

1. **Write Redirection:** All file-writing requests are routed to MergerFS which forces writing to the SSD (Tier B) via the `category.create=ff` policy.
2. **Same-Disk Staging:** Files undergo staging in a hidden `.staging/` directory on the SSD before atomic metadata deployment, preventing long sequential writes directly on HDDs.
3. **Capacity Thresholds:** If the SSD hits 85% capacity, a capacity-triggered move is executed, spinning up HDDs only if necessary.
4. **Activity-Aware Mover:** Under normal operations, the mover script checks HDD power status via `hdparm -C` and relocates files *only* when the mechanical disks are already spun up by other reads.

---

## MergerFS Mount Optimization Parameters

To achieve optimal performance and guarantee HDD spindowns, the MergerFS pool must be mounted with the following specific flags in NixOS:

| Option | Value | Operational Purpose |
|:---|:---|:---|
| `category.create` | `ff` | *First Found.* Directs all new write operations strictly to the first available pool member (the Tier B SSD cache). |
| `minfreespace` | `50G` | *Minimum Free Space.* Prevents any pool member from running out of sectors, avoiding disk full lockups. |
| `dropcacheonclose` | `true` | *Drop Cache on Close.* Forces immediate RAM cache flushes upon file closures. This stops the kernel from keeping sectors dirty, allowing `hd-idle` to trigger HDD spindown on time. |
| `defaults,allow_other` | (Standard) | Standard fuse parameters to enable multi-user file access. |

---

## Operational Procedures

### Setting up the Media Group (GID 169) & Setgid

To prevent permission drift (where downloads are locked to one user and invisible to Jellyfin), apply the Setgid bit globally:

```bash
# 1. Create the central media group (handled natively via NixOS configuration)
# groupadd -g 169 media (Imperative equivalent)

# 2. Establish ownership on active folders
chown -R root:media /mnt/fast_pool/downloads
chown -R root:media /mnt/media

# 3. Force inheritance via the Setgid bit
chmod -R 775 /mnt/fast_pool/downloads
chmod -R 775 /mnt/media
find /mnt/fast_pool/downloads -type d -exec chmod g+s {} +
find /mnt/media -type d -exec chmod g+s {} +
```

### The Smart SSD Mover Strategy

The smart mover is run via systemd timer (e.g. daily at 04:00 AM) or triggered manually:

```bash
#!/usr/bin/env bash
# Smart-Mover execution pattern outline (Reference Implementation)
set -euo pipefail

SSD_PATH="/mnt/fast_pool/downloads"
HDD_PATH="/mnt/media"
THRESHOLD=85

# 1. Check current SSD cache capacity
CACHE_USAGE=$(df -h "$SSD_PATH" | awk 'NR==2 {print $5}' | sed 's/%//')

migrate_files() {
    echo "Starting local file migration via rclone..."
    rclone move "$SSD_PATH" "$HDD_PATH" \
      --min-age "14d" \
      --delete-empty-src-dirs \
      --transfers=4 \
      --checkers=8 \
      --exclude "**/incomplete/**" \
      --exclude "**/.staging/**" \
      -v \
      --log-file=/var/log/rclone-mover.log
}

if [ "$CACHE_USAGE" -ge "$THRESHOLD" ]; then
    echo "SSD cache capacity critical (${CACHE_USAGE}%). Forcing migration to HDDs..."
    migrate_files
elif hdparm -C /dev/disk/by-label/DISK_STORAGE_1 | grep -q "active/idle"; then
    echo "HDDs are already spinning. Moving staged downloads..."
    migrate_files
else
    echo "HDDs are spun down, and SSD usage is safe (${CACHE_USAGE}%). Sleeping to conserve power."
fi
```

---

## Verification & Troubleshooting

### Check Disk Spindown State

```bash
# Verify power status of your storage drives without waking them up
hdparm -C /dev/disk/by-label/DISK_STORAGE_*
```

### Check MergerFS Pool Parameters

```bash
# Query active MergerFS configuration
mount | grep mergerfs
```

---

## Known Failure Modes

| Symptom | Likely Cause | Operational Fix |
|:---|:---|:---|
| HDDs never spin down | `dropcacheonclose` is false or a service is constantly writing log files to Tier C | Mount MergerFS with `dropcacheonclose=true`. Inspect active file locks using `lsof /mnt/media`. |
| Permission Denied between Radarr and Jellyfin | A new subdirectory was created without GID 169 inheritance | Re-execute the Setgid bit command: `find /mnt/media -type d -exec chmod g+s {} +`. Verify NixOS service users are members of the `media` group. |
| Mover fills HDD to 100% | `minfreespace` was omitted or set too low | Enforce `minfreespace=50G` in the MergerFS mount options inside `30-storage.nix`. |
