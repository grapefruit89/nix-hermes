# NixOS Data Management Tools (rsync, rclone, restic) - SSoT Documentation

This guide provides a systematic analysis and metadata reference for the three central data management tools integrated into our NixOS-based homelab.

---

## 📋 1. NixOS-Specific Issue & Risk Analysis

### 1.1 rsync (RsyncProject/rsync)
- **IPv6 Kernel Disabling (`ipv6.disable`)**: When IPv6 is completely disabled via kernel parameters (`boot.kernelParams = [ "ipv6.disable=1" ];`), rsync daemon startup will crash or fail to bind if it attempts to listen on IPv6 loopback or interfaces without explicit IPv4-only configurations.
- **Buffer-Overflows & Segfaults**: Large file transfers with deep directory structures and high concurrency can occasionally hit memory buffer limit segfaults on resource-constrained systems, requiring fine-tuning of `--max-alloc` limits.
- **IPv6 Colon Separator Conflict**: Because IPv6 addresses contain colons, rsync's URI parser can misinterpret remote connection destinations (e.g. `[2001:db8::1]:/path`) if not enclosed in square brackets, leading to parse errors.
- **WSL & Read-Only Filesystems**: When running rsync inside WSL environments, permission translation (`metadata` mount option) issues can trigger false file-attribute mismatches or failed write-permissions on read-only mounted Windows volumes.

### 1.2 rclone (rclone/rclone)
- **OneDrive Personal Vault**: Rclone cannot access files stored in the OneDrive "Personal Vault" folder because Microsoft restricts APIs for these secure directories, resulting in silent skips or file-not-found errors during sync.
- **SOPS-Secrets Boot Injection Race**: Since rclone config is often loaded via `sops-nix` dynamically at boot, systemd services referencing rclone config files can trigger race conditions if they start before `sops-nix.service` completes decrypting secrets to `/run/secrets/`.
- **Systemd specialfs / remount Compatibility**: Mounting rclone remotes via systemd mounts can cause lockups or fail if standard FUSE `remount` options are passed to special filesystems without FUSE-specific flags.
- **ProtonDrive Segfaults**: Rclone's ProtonDrive backend has experienced runtime panic segfaults under high CPU load or concurrent chunk uploads due to memory allocation quirks in the underlying Go API client.
- **Wrapper FUSE3 Dependency**: Rclone mounts require FUSE to interact with the kernel. The NixOS package must be wrapped to dynamically find the setuid helper binary at `/run/wrappers/bin/fusermount3` because binaries inside the Nix store cannot have setuid permissions.
- **Systemd Logging Deadlocks**: High-velocity logging (e.g. `rclone -vv` inside a systemd timer) can clog systemd-journald and trigger thread deadlocks if stdout buffers saturate.

### 1.3 restic (restic/restic)
- **SOPS-Nix Shellcheck Failures**: When embedding restic environment files (e.g. `AWS_ACCESS_KEY`) using multiline strings decrypted by `sops-nix`, standard syntax checkers or Nix linters can throw errors if variables aren't properly escaped in writeShellScript blocks.
- **Prometheus Exporter Permissions**: The restic exporter needs read/write permissions to restic's local cache directory (`/var/cache/restic/`). If the exporter service runs as a non-root system user, it can fail to update status reports.
- **Systemd Hardening and Root Backups**: Running restic backups as root can bypass sandboxing. To mitigate security risks, systemd unit configurations must apply strict rules (e.g., `ProtectSystem = "strict"`) while preserving read access to `/persist` state.
- **Network Wait Deadlock**: Restic systemd timers starting immediately at boot can fail if they attempt to contact remote S3 or SFTP repositories before network interfaces are fully initialized and Tailscale is online.
- **Missing `--files-from` Checks**: Passing empty lists to restic via script parameters can lead it to assume all directories should be scanned, creating duplicate backups.

---

## 📚 2. Repository Metadata & Declarative Sources

### 2.1 rsync
- **Official Name**: `RsyncProject/rsync`
- **Primary URL**: `https://github.com/RsyncProject/rsync`
- **License**: GNU General Public License v3 (GPLv3)
- **Release Cycle**: Stable (periodic major releases)
- **Purpose in Homelab**: High-speed local folder synchronizations and legacy delta transfers.
- **NixOS Module Integration**: Fully supported via the systemwide `services.rsyncd` module.
- **NixOS-Specific Patches**: Packed in nixpkgs with standard security hardening flags and standard Glibc compatibility patches.

### 2.2 rclone
- **Official Name**: `rclone/rclone`
- **Primary URL**: `https://github.com/rclone/rclone`
- **License**: MIT License
- **Release Cycle**: Stable (frequent minor updates)
- **Purpose in Homelab**: Cloud sync bridge (Google Drive, S3, etc.) and file-mover backend for Tier B-to-Tier C transfers.
- **NixOS Module Integration**: Supported via system-wide systemd services or user-level configuration using the Home-Manager option `programs.rclone.enable`.
- **NixOS-Specific Patches**: Custom nixpkgs wrapper that replaces local `fusermount` calls with host-level `/run/wrappers/bin/fusermount3` to ensure FUSE works seamlessly without raw root execution inside the Nix store.

### 2.3 restic
- **Official Name**: `restic/restic`
- **Primary URL**: `https://github.com/restic/restic`
- **License**: BSD 2-Clause "Simplified" License
- **Release Cycle**: Stable (regular performance and security releases)
- **Purpose in Homelab**: Offsite backup engine with deduplication and client-side encryption.
- **NixOS Module Integration**: canonical NixOS integration via `services.restic.backups.<name>` which automates systemd unit creation, timers, and password files.
- **NixOS-Specific Patches**: Wrapped with native CA certificates package integration to ensure TLS handshakes with S3 and HTTPS endpoints resolve successfully under strict systemd sandbox environments.
