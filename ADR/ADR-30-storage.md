---
title:        "ADR-30: Hybrid Pooling, ext4 + MergerFS Media Stack, & Pending Disks Watcher"
domain:       30
folder:       30-storage
status:       accepted
date:         2026-05-26
deciders:     [moritz]
review_after: 2027-05-26
links:
  guide:   30-storage.md
  modules:
    - Nix Files/modules/30-storage.nix
  supersedes: [ADR_435_Mnt_Zfs_Mergerfs_Physisch_Das.md, ADR_478_Die_Zfs_Weg_Du_Medien.md, ADR_815_Das_Zfs_Mnt_Ist_Mergerfs.md, ADR_187_Tier_Label_Disk_Filesystems_Pending.md]
---

# ADR-30: Hybrid Pooling, ext4 + MergerFS Media Stack, & Pending Disks Watcher

> **We establish a hybrid storage pooling model for our homelab. We utilize local SSD storage (Btrfs/ext4) specifically for high-integrity, irreplaceable files (documents, databases) requiring automated backups, while using an ext4 JBOD array pooled via MergerFS for our media collection. We reject SnapRAID due to sync lag, and deploy the automated 'nixhome-pending-watcher' watchdog timer to detect unlabelled disks dynamically.**

---

## Context

**What is the problem?**
Managing diverse homelab storage assets requires balancing physical drive longevity, performance, and data security:
1. **HDD Spindown Wear:** Pooling all mechanical disks under traditional RAID systems (ZFS mirror, mdadm) forces all drives to spin up simultaneously during any read request, creating severe hardware wear and heat.
2. **SnapRAID Inadequacy:** Utilizing SnapRAID for media requires manual cron-based parity syncing. If a disk fails before the daily sync completes, downloads added during that window are lost forever.
3. **Impermanence Disk Identification:** Epic stateless boots (tmpfs on `/`) make identifying hot-plugged raw drives complex. Without automatic labelling, the server fails to mount storage partitions seamlessly.

**Why does this matter?**
A premium homelab architecture requires silent, energy-efficient mechanical disks with a 99% spindown idle time and automated hardware discovery tools to avoid manual mount configurations.

---

## Considered Alternatives

### Option A: SSD Tier (Irreplaceable Core) + MergerFS (Media Array) + Pending Watcher ← CHOSEN

**What it is:**
Unersetzbare Daten (databases, secrets, configuration) reside on the local SSD tier `/persist` (ext4/Btrfs) where automated Restic backups are active. The rest of the media stack (replaceable movies, TV shows) resides on individual ext4 disks pooled virtually under a single `/mnt/media` mountpoint via MergerFS. New write requests are routed to the SSD cache (Tier B) via the `category.create=ff` policy. Newly plugged unformatted disks are identified by the `nixhome-pending-watcher` service and written as `.pending` states to `/run/nixhome-pending-disks/` to alert the administrator.

**Pros:**
- **Optimal HDD Spindown:** Reading a movie spins up *only* the single disk containing that file. The other mechanical drives remain completely sleeping.
- **Immediate Data Safety:** No SnapRAID sync lag. Files are written directly to Tier B (SSD) and staged, guaranteeing instant write operations.
- **Zero Drift Storage:** Hybrid virtualization under a single `/mnt/media` pool allows Jellyfin to see files seamlessly as if they were in a single folder.
- **Automated Discovery:** Hot-plugged drives are flagged instantly by the pending disks watcher.

**Cons:**
- SSD storage is limited by local drive capacity.

---

### Option B: Monolithic SnapRAID Media Pool ← REJECTED

**What it is:** Running ext4 JBOD arrays with a dedicated SnapRAID parity disk.

**Why rejected:**
High operational overhead. The daily parity sync creates a vulnerability window where recently fetched media is unprotected. It also requires manually running scrubs and sync commands continuously.

---

## Decision

**We choose Option A.**

We declare:
1. **Hybrid Storage:** Enforce local SSD storage (Btrfs/ext4) for irreplaceable data and ext4 + MergerFS for media pooling.
2. **Mount Optimizations:** Mount MergerFS pool with `category.create=ff`, `minfreespace=50G`, and `dropcacheonclose=true` parameters.
3. **Pending Disks Watchdog:** Periodic execution of the `nixhome-pending-watcher` timer.
4. **Offline Cache Protection:** Standardize on Restic cloud encryption routines for Tier A state.

---

## Consequences

**Positive:**
- **Silent & Clean Operation:** HDDs remain spun down 99% of the time, lowering noise and energy consumption.
- **Dynamic Drive Expansion:** Hot-plugging a new disk requires zero service restarts; simply format it ext4, label it, and MergerFS dynamically appends the new branch.
- **Zero-touch Recovery:** Backup recovery is extremely quick and secure.

**Negative:**
- No parity protection for the media array (if an ext4 media drive dies, only the files on that specific drive are lost and must be re-downloaded via the Arrs).

---

## Validation

- **Signal:** MergerFS pool mounts successfully, unlabelled drives are correctly cataloged as `.pending` in `/run/`, and `hdparm -C` confirms individual disks spin down autonomously.
- **Review frequency:** Every 12 months.