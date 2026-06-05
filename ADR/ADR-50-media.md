---
title:        "ADR-50: Unified Media Stack, QSV Acceleration, & Radarr Quality Rules"
domain:       50
folder:       50-media
status:       accepted
date:         2026-05-26
deciders:     [moritz]
review_after: 2027-05-26
links:
  guide:   50-media.md
  modules:
    - Nix Files/modules/50-media/default.nix
  supersedes: [radarr_qualityprofiles.json, radarr_customformats.json]
---

# ADR-50: Unified Media Stack, QSV Acceleration, & Radarr Quality Rules

> **We establish a unified, native systemd-sandboxed Media Stack inside NixOS featuring Jellyfin with Intel QuickSync (QSV) hardware acceleration, alongside a declarative, automated quality profile structure (including the 'Fernseher' profile and custom format score weights) for Radarr and Sonarr. This decouples the Media Stack from container overhead and guarantees high-fidelity, space-efficient releases.**

---

## Context

**What is the problem?**
Managing a high-performance homelab media stack introduces several engineering challenges:
1. **GPU Acceleration Overhead:** Running media services inside Docker wrappers makes hardware decoding (Intel UHD 630 QuickSync) complex and prone to permission resets upon container updates.
2. **Permission Conflicts:** Media downloaders (SABnzbd) and management tools (Radarr, Sonarr) often suffer from silent file access conflicts and UID/GID drift.
3. **Quality & Space Sprawl:** Without explicit, machine-readable quality profiles and custom formats, automated fetch processes download low-quality CAM releases, redundant multi-lingual files, or oversized files that waste mechanical disk capacity.

**Why does this matter?**
To achieve an autonomous and highly responsive homelab, we need a media stack that is isolated from the host filesystem, uses hardware resources natively, and enforces strict, declarative content rules.

---

## Considered Alternatives

### Option A: Native NixOS systemd Services + Declarative JSON Profiles ← CHOSEN

**What it is:**
We deploy Jellyfin, Sonarr, Radarr, Readarr, Prowlarr, and SABnzbd as native systemd services inside `50-media.nix`, locked under the central GID 169 (`media` group). We leverage systemd devices (`/dev/dri/renderD128`) for native QSV acceleration. Content filtering is managed via declarative JSON profiles (`Any`, `Fernseher`) that block cam/screener/workprint releases and apply scoring rules (upvoting AV1/x265, downvoting giant files over 12GB).

**Pros:**
- **Zero Overhead QSV:** Native access to the Intel compute runtime ensures efficient hardware transcoding with low CPU overhead.
- **Robust Sandboxing:** Systemd locks directories strictly (`ReadWritePaths`, `PrivateDevices = false` only for Jellyfin's card0 access).
- **Quality Autonomy:** The `Fernseher` profile avoids "Absoluter Dreck" and oversized releases completely, saving mechanical HDD space.
- **Unified Permission Set:** Setgid GID 169 enforces flawless inter-service file transfer.

**Cons:**
- Upstreaming the JSON profiles into Radarr/Sonarr requires an initial API import step.

---

### Option B: Docker-Compose & Traefik Wrappers ← REJECTED

**What it is:**
Running the entire media stack inside a Docker-Compose file managed by a Traefik proxy.

**Why rejected:**
This legacy pattern is highly deprecated. Docker layers introduce significant network overhead, make system-level hardware passthrough fragile, and bypass the central, declarative purity of NixOS and Caddy gateways.

---

## Decision

**We choose Option A.**

We mandate:
1. **Jellyfin Acceleration:** Native Intel UHD 630 graphics driver offloading.
2. **Global Media Group:** Bind all Arr services under the shared GID 169 (`media`).
3. **Content Filtering:** Enforce the `Fernseher` quality profile and custom format score weightings.
4. **API deployment:** Standardize cURL-based imports for profiles to maintain infrastructure portability.
5. **Centralized Locale Sync & Declarative Settings-Sync (Sources: nixarr & nixflix):** We adopt and adapt the settings-sync approach and connective tissue concepts from the **Nixarr** (https://github.com/nix-media-server/nixarr) and **Nixflix** (https://github.com/kiriwalawren/nixflix) projects. We implement a native systemd oneshot service `media-stack-config-sync` that:
   - **Dynamic Language Derivation:** Dynamically extracts user-declared language preferences (`config.my.configs.locale`) from the central `/users` preferences.
   - **Multi-app Auto-injection:** Rewrites Jellyfin configuration (`system.xml` via Python) and SABnzbd configuration (`sabnzbd.ini` via sed) on boot to ensure zero manual language drift.
   - **API-based Profile Enforcement:** Automatically checks and enforces default quality profiles in Sonarr (`Deutsch` ID 1) and Radarr (`Fernseher` ID 4) via their REST APIs, migrating any legacy profiles.
   - **Automated Bootstrap:** Configures the SceneNZBs indexer and maps SABnzbd categories (`tv`, `movies`) at boot, ensuring the entire media ecosystem is fully unified, local, and 100% declarative.
6. **Proactive iGPU & OpenCL Sandbox Mappings:** We configure `hardware.graphics` directly inside the module and map `/run/opengl-driver` into the Jellyfin systemd sandbox `ReadOnlyPaths`. This prevents OpenCL tonemapping library crashes under strict systemd hardening.
7. **Flächendeckende GID 169 UMask Enforcement:** We enforce `UMask = "0002"` on the systemd service configurations of Jellyfin, Sonarr, Radarr, Readarr, and SABnzbd to fully eliminate permission drift and manual file access corrections in `/data/media` and `/data/downloads`.
8. **Usenet RAM-Disk Cache (SSD Longevity):** We mount a RAM-backed `RuntimeDirectory = "sabnzbd-tmp"` for SABnzbd under `/run/sabnzbd-tmp/` to buffer incoming temporary chunks in memory, massively boosting write speeds and protecting mechanical or solid-state caches from wear.

---

## Consequences

**Positive:**
- **Incredible Efficiency:** GPU transcoding runs flawlessly at negligible CPU usage.
- **Zero Permission Issues:** Shared GID 169 + systemd UMask 0002 ensures flawless inter-service read/write operations without permission drift.
- **Smart Cataloging:** High-quality releases are prioritized automatically without manual screening.
- **SSD Protection:** RAM caching saves terabytes of SSD wear (TBW) annually.
- **100% Centralized Purity:** A single language edit in `/users` dynamically propagates across Jellyfin, SABnzbd, Sonarr, and Radarr at boot!

**Negative:**
- Radarr/Sonarr API endpoints must be reachable to apply custom format payloads.

---

## Validation

- **Signal:** systemd unit health responds, `intel_gpu_top` shows active video rendering, and Radarr releases matching custom format profiles get imported successfully.
- **Review frequency:** Every 12 months.