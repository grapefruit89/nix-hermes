---
title: "Storage Guide: Appdata & Cache Separation for High-Efficiency Backups"
domain: 30
folder: 30-storage
status: active
complexity: 3
last_reviewed: 2026-06-02
links:
  adr:     ADR-30-storage.md
---

# Storage Guide: Appdata & Cache Separation

To achieve fast, cheap, and lightweight backups, we separate irreplaceable configurations (Appdata) from rebuildable, heavy caches and metadata (Appdata Cache).

---

## The Core Concept

```
┌────────────────────────────────────────────────────────┐
│                   Docker Appdata Share                 │
└───────────────────────────┬────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
  ┌───────────────────┐           ┌───────────────────┐
  │   appdata/        │           │   appdata_cache/  │
  │   (Tier A)        │           │   (Tier B / C)    │
  ├───────────────────┤           ├───────────────────┤
  │ - Settings/Configs│           │ - Cover images    │
  │ - SQLite DBs      │           │ - Poster art      │
  │ - Key files       │           │ - Transcode caches│
  ├───────────────────┤           ├───────────────────┤
  │ BACKED UP DAILY   │           │ EXCLUDED FROM BU  │
  └───────────────────┘           └───────────────────┘
```

1. **Appdata (`/mnt/docker_and_vm/appdata/`)**: Contains only the core configuration files, databases, and custom settings. This directory is lightweight (typically < 1-2 GB total) and is backed up to offsite secure storage daily.
2. **Appdata Cache (`/mnt/docker_and_vm/appdata_cache/`)**: Contains bulk metadata, covers, fanart, transcode files, and scrapers. This directory is heavy (often 50-200 GB) but is 100% rebuildable from public APIs. It is excluded from backups.

---

## Container Mapping Standards

### 1. Jellyfin
- **Core Configuration (`/config`)**: `/mnt/docker_and_vm/appdata/Jellyfin` (Backed up)
- **Metadata Cache (`/config/metadata`)**: `/mnt/docker_and_vm/appdata_cache/Jellyfin/metadata` (Excluded)
- **Transcode Cache (`/transcode`)**: `/dev/shm` (RAM disk - zero disk wear, volatile) or `/mnt/docker_and_vm/appdata_cache/Jellyfin/transcode`

### 2. Audiobookshelf
- **Core Configuration (`/config`)**: `/mnt/docker_and_vm/appdata/audiobookshelf` (Backed up)
- **Metadata Cache (`/metadata`)**: `/mnt/docker_and_vm/appdata_cache/audiobookshelf/metadata` (Excluded)

### 3. Sonarr / Radarr / Prowlarr
These containers store their databases, configuration files, and downloaded media covers in a single directory. To separate them:
- **Core Mapping (`/config`)**: `/mnt/docker_and_vm/appdata/[container]`
- **Backup Exclusions**: Configure your backup tool (e.g. Restic) to ignore the following directories inside the configuration path:
  - `**/MediaCover/` (Covers can be redownloaded instantly)
  - `**/Backups/` (In-app database backups are redundant if the folder is already backed up)

---

## Restic Backup Exclusions Standard

When backing up `/mnt/docker_and_vm/appdata/` via NixOS or Unraid backups, enforce the following command flags or exclusion file:

```bash
# Restic backup invocation with strict exclusions
restic backup /mnt/docker_and_vm/appdata/ \
  --exclude="**/MediaCover" \
  --exclude="**/Backups" \
  --exclude="**/Cache" \
  --exclude="**/logs" \
  --exclude="**/tmp"
```
