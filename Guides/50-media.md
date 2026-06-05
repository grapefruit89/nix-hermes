---
title: "Media Domain Guide: Sandboxed Stack & Radarr API Profile Import"
domain: 50
folder: 50-media
status: active
complexity: 3
last_reviewed: 2026-05-26
links:
  adr:     ADR-50-media.md
  modules:
    - path: Nix Files/modules/50-media/default.nix
---

# Media Domain Guide: Sandboxed Stack & Radarr API Profile Import

> **Operational guide for managing the sandboxed media stack (Jellyfin, Sonarr, Radarr, SABnzbd), configuring Intel QSV GPU acceleration, applying global GID 169 media permissions, and bulk-loading custom quality formats/profiles via API payloads.**
> Guarantees an automated, high-fidelity media library and seamless inter-service downloads.

---

## Prerequisites

Before deploying or diagnosing media services, verify:
- [x] Domain `00-core` and `10-network` are healthy.
- [x] GPU hardware acceleration is active (Intel UHD 630 on Fujitsu Q958).
- [x] User-specific API key for Radarr or Sonarr is generated and available in SOPS decrypted path `/run/secrets/`.

---

## How It Works

```
[User Request / Seerr]
         │
         ▼ (Auto-discovery)
[Sonarr / Radarr (Port 8989 / 7878)] ──(JSON Quality Profiles)──► [Selects Release]
         │
         ▼ (Triggers Download)
[SABnzbd (Port 8080)] ──(Saves to /data/downloads - GID 169)──► [Move to /data/media]
         │
         ▼ (Decoded natively on GPU)
[Jellyfin (Port 8096)] ◄──(Intel QSV hardware acceleration /dev/dri)
```

1. **Service Sandboxing:** Services run inside individual systemd units, locked to the shared GID 169 (`media` group).
2. **GPU Passthrough:** Jellyfin connects directly to the raw GPU device nodes (`/dev/dri/card0` and `/dev/dri/renderD128`) with zero host abstraction wrappers.
3. **Smart Ingestion:** Radarr/Sonarr use quality filters to prevent downloading "Absoluter Dreck" (CAM/TS), enforcing custom bitrates and x265/AV1 priorities.
4. **API Integration:** Quality profiles are pushed directly to the REST endpoints of Radarr and Sonarr via automated HTTP payload queries.

---

## Operational Procedures

### Declarative Settings & Application Sync (nixarr & nixflix Style)

We adopt the highly elegant declarative settings synchronization model and "connective tissue" automation concepts popularized by the **Nixarr** (https://github.com/nix-media-server/nixarr) and **Nixflix** (https://github.com/kiriwalawren/nixflix) projects. Since external Nix flakes are an antipattern for this system, we have copied and adapted this logic natively into `50-media.nix`:

*   **The Sync Daemon:** The `media-stack-config-sync` systemd service runs as a privileged `oneshot` service on boot.
*   **Centralized SSoT Language Sync:** It reads your centralized locale parameters (e.g. `language = "de"`) from `/users/moritz/preferences.nix` and dynamically syncs them at boot across:
    1.  **Jellyfin:** Rewrites `/var/lib/jellyfin/config/system.xml` to set PreferredMetadataLanguage, MetadataCountryCode, and UICulture.
    2.  **SABnzbd:** Updates `language = de` directly in `/var/lib/sabnzbd/sabnzbd.ini`.
    3.  **Sonarr & Radarr:** Inspects all series and movies, migrating any using the Englisch profiles (ID 4 / 11) to the deklarierten German profiles (ID 1 / 4) via their REST APIs.
*   **API Key Extraction:** It automatically scrapes the API keys of Prowlarr, Sonarr, and Radarr from their decrypted `/var/lib/` configuration files, completely bypassing manual key entry or external secrets.
*   **Auto-Configuration:** It verifies and ensures that:
    1.  The **SceneNZBs** indexer is present in Prowlarr (using a placeholder API key that you can overwrite in the GUI).
    2.  **Sonarr** and **Radarr** are linked as applications in Prowlarr.
    3.  **SABnzbd** is automatically added and configured as the central Usenet download client inside both **Sonarr** (using category `tv`) and **Radarr** (using category `movies`) by reading the decrypted sops-secret or `sabnzbd.ini` API key.
*   **Instant Push:** It triggers an immediate `ApplicationsSync` command so Prowlarr instantly pushes the indexers to both Sonarr and Radarr, ensuring zero delay.

To trigger this sync manually, simply restart the systemd unit:
```bash
systemctl restart media-stack-config-sync
```

### Importing Custom Quality Profiles & Formats

To bulk-load the JSON profiles into your active Radarr or Sonarr instance, execute these REST commands:

```bash
# 1. Define instance endpoints and credentials
API_KEY="your_api_key_here"
RADARR_URL="http://127.0.0.1:7878/api/v3"

# 2. Import Custom Formats (e.g. Language filters)
curl -X POST -H "Content-Type: application/json" \
     -H "X-Api-Key: $API_KEY" \
     -d @radarr_customformats.json \
     "$RADARR_URL/customformat"

# 3. Import Quality Profiles (e.g. Fernseher configuration)
curl -X POST -H "Content-Type: application/json" \
     -H "X-Api-Key: $API_KEY" \
     -d @radarr_qualityprofiles.json \
     "$RADARR_URL/qualityprofile"

# 4. Import Quality Definitions (Bitrates mapping)
curl -X PUT -H "Content-Type: application/json" \
     -H "X-Api-Key: $API_KEY" \
     -d @radarr_qualitydefinition.json \
     "$RADARR_URL/qualitydefinition"
```

### Enforcing GID 169 (media) Permissions Standard

To resolve transfer permission conflicts between SABnzbd and Radarr/Sonarr, verify directory ownerships:

```bash
# Set base directory permissions recursively
chown -R root:media /data/downloads
chown -R root:media /data/media
chmod -R 775 /data/downloads
chmod -R 775 /data/media

# Enforce Setgid bit for automatic subfolder inheritance
find /data/downloads -type d -exec chmod g+s {} +
find /data/media -type d -exec chmod g+s {} +
```

### Diagnosing & Optimizing Intel QSV GPU Transcoding

#### 1. Verifying Hardware & Driver Loading
```bash
# 1. Verify that your system detects the graphics render node
ls -l /dev/dri

# 2. Check if GuC/HuC firmware loading is active (critical for UHD 630 HEVC offloading!)
# Look for "GuC firmware load: Succeeded" in the output
sudo journalctl -k | grep -E "guc|huc|i915"

# 3. Run real-time GPU load diagnostics (Requires intel-gpu-tools)
# Look for 'Video' engine usage when playing a high-bitrate file
intel_gpu_top

# 4. Check Jellyfin systemd unit hardware offload capabilities
systemctl status jellyfin
```

#### 2. SSD Longevity Optimization (RAM-backed tmpfs Transcoding)
To prevent massive write wear (TBW) on your SSD, we have mapped a RAM-backed `tmpfs` directly into the Jellyfin sandbox at `/run/jellyfin-transcode`.
*   **Operational Action:** Inside the Jellyfin Web GUI under **Dashboard > Playback**, set the **Transcoding temporary path** to `/run/jellyfin-transcode`. This shifts all transcoding write overhead to RAM!

#### 3. High-Speed Usenet RAM Cache (SABnzbd temporary downloads)
To boost Usenet speeds and completely protect your physical disks from heavy block-writing wear, we have mounted a systemd RAM-backed `tmpfs` directory directly inside the SABnzbd service sandbox under `/run/sabnzbd-tmp/`.
*   **Operational Action:** Inside the SABnzbd Web GUI under **Config > General**, set the **Temporary Download Folder** to `/run/sabnzbd-tmp`. All incoming temporary chunks will be buffered in high-performance RAM before being assembled into your permanent `/data/downloads` directory!

#### 4. Subtitle "Tofu" Box Prevention
Headless servers often lack standard fonts, causing subtitles to render as empty squares ("tofu") or crash during burn-in. We have declared standard fonts system-wide (DejaVu, Liberation, Noto CJK multilingual fonts).
*   **Jellyfin Configuration:** In the Jellyfin Web GUI under **Dashboard > Playback**, ensure **Fallback font path** is empty or set to `/run/current-system/sw/share/fonts/truetype` so Jellyfin discovers all system fonts automatically!

#### 5. OpenCL HDR-to-SDR Tone Mapping Sandbox Verification
Thanks to mapping `/run/opengl-driver` inside Jellyfin's `ReadOnlyPaths` and declaring `ocl-icd` in the system packages, Jellyfin's ffmpeg can natively access the OpenCL compute layers.
*   **Verification:** Play a 4K HDR10/HEVC file and force transcoding to 1080p SDR. Under **Dashboard > Active Sessions**, click the info button to confirm that hardware tone mapping is active and that no "OpenCL not found" or "Access Denied" errors appear in the Jellyfin logs (`journalctl -u jellyfin`).

#### 6. Flawless Permissions (Automatic UMask 0002)
We have completely automated permission drift prevention! The systemd service configs for Jellyfin, Sonarr, Radarr, Readarr, and SABnzbd enforce `UMask = "0002"`.
*   **Benefit:** Manual permission repairs (`chmod` and `chown` runs) are no longer needed. Any file written by the download client or imported by the media managers automatically receives group-writable permissions (`rw-rw-r--` or `rwxrwxr-x`) matching GID 169 (`media`), completely eliminating access issues.

---

## Verification Commands

These commands must all pass to confirm a healthy Media stack deployment:

```bash
# 1. Verify all stack services are running and stable
for service in jellyfin sonarr radarr readarr prowlarr sabnzbd; do
    systemctl is-active --quiet $service && echo "PASS: $service is active" || echo "FAIL: $service is down"
done

# 2. Check that active sockets are bound to internal local ports
ss -tlnp | grep -E "8989|7878|8080|8096"

# 3. Run vainfo to verify active VA-API driver loading (iHD driver)
vainfo
```

---

## Known Failure Modes

| Symptom | Likely Cause | Fix |
|:---|:---|:---|
| Transcoding fails with hardware error | renderD128 node has wrong permissions | Ensure the `jellyfin` user belongs to the `video` and `render` groups inside `50-media.nix`. |
| "Access to path is denied" inside Sonarr | Parent directory is missing the Setgid permission | Re-execute: `find /data/downloads -type d -exec chmod g+s {} +`. Verify that `sabnzbd` runs with `umask 002`. |
| API Import throws 401 Unauthorized | API key is invalid or has expired | Retrieve the updated API key from the Radarr settings under `Settings > General > Security`. |
| Rebuild fails with sandbox block | PrivateDevices is active on Jellyfin | Jellyfin *must* have `PrivateDevices = false` inside `50-media.nix` to allow GPU rendering node access. |

---

## NixOS-Native Wunschliste Gotchas: Media Stack Runtimes & Configs

### Insecure .NET Runtimes (Radarr/Sonarr Build Failures)
* **The Gotcha (Deprecated Packages Block Rebuilds):** Radarr, Sonarr, and Lidarr frequently rely on older or end-of-life .NET SDK runtimes or specific OpenSSL libraries (e.g. `dotnet-sdk-6.0.428` or `openssl-1.1.1w`). When these are deprecated, NixOS will refuse to build your configuration, throwing a security risk warning.
* **The Resolution:** Add the required insecure packages to the permitted list in `nixpkgs.config` inside your host configuration `hosts/q958/configuration.nix`:
  ```nix
  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-sdk-6.0.428"
    "openssl-1.1.1w"
  ];
  ```

### SABnzbd Configuration Lock & Start Failures
* **The Gotcha (GUI Settings Overwritten on Reboot):** By default, if the NixOS SABnzbd module manages the configuration file declaratively, any modifications made in the web interface (like server lists, indexers, or categories) will be wiped out when the system restarts.
* **The Resolution:** Enable declarative settings merging with write support by setting `services.sabnzbd.allowConfigWrite = true;` and setting `services.sabnzbd.configFile = null;` to suppress deprecation warnings. Ensure `umask = 002` is active in systemd to maintain global GID 169 permission standards for newly downloaded media files.