---
title: "Gaming & Game Server Management: Native FHS Sandbox & AMP"
domain: 80
folder: 80-gaming
status: active
complexity: 3
last_reviewed: 2026-05-27
links:
  adr:     ADR-80-gaming.md
  modules:
    - path: modules/80-gaming.nix
      anchor: amp-service
---

# Gaming & Game Server Management: Native FHS Sandbox & AMP

> **Manages bare-metal execution of game server instances (Minecraft, SteamCMD, Factorio, etc.) through AMP (Application Management Panel) wrapped in a native, highly secure Filesystem Hierarchy Standard (FHS) systemd sandbox.**

---

## Prerequisites

Before deploying or maintaining anything in this domain, the following must be true:

- [x] Domain `00-core` is healthy and active.
- [x] Domain `10-network` (Caddy reverse proxy) is healthy and active.
- [x] Disk `/data` (SSD Tier A) is mounted and has write access on `/var/lib/amp` (persistent state directory).

---

## How It Works (Architecture in Plain Language)

1. **FHS Environment Layer:** NixOS packages do not have standard paths (like `/lib64`), which causes unpatched game binaries (SteamCMD, Java, Dotnet) to crash. The `amp-fhs` package created in `80-gaming.nix` wraps all dynamic libraries in a standard FHS sandbox.
2. **AMP Instance Daemon:** The systemd `amp.service` executes the FHS wrapper which starts the AMP daemon manager under the system user `amp` on port `8085`.
3. **Caddy Reverse Proxy:** External traffic is routed from `https://amp.m7c5.de` directly to `127.0.0.1:8085` with zero SSO overhead to prevent cookie session collisions with AMP's own RBAC authentication.

---

## Operational Procedures

### First Deploy & Bootstrapping

If you are setting up AMP for the very first time on a fresh system, follow these exact bootstrapping instructions:

```bash
# 1. Switch to the dedicated 'amp' system user
sudo -u amp -s

# 2. Enter the FHS sandbox environment manually
amp-fhs

# 3. Quickstart bootstrap command to generate the ADS (core manager) instance
# Replace 'admin' and 'YourPasswordHere' with your secure credentials
ampinstmgr QuickStart admin YourPasswordHere 0.0.0.0 8085

# 4. Exit the FHS environment and return to normal shell
exit
exit

# 5. Start the systemd service to manage all instances automatically
sudo systemctl start amp.service
sudo systemctl enable amp.service
```

### Routine Maintenance & Instance Management

Once bootstrapped, instances can be managed via the Web UI at `https://amp.m7c5.de`.
However, CLI commands are executed as the `amp` user inside the FHS environment:

```bash
# Enter FHS shell to check running instances
sudo -u amp amp-fhs -c "ampinstmgr Status"

# Restart all instances gracefully
sudo -u amp amp-fhs -c "ampinstmgr restartall"

# Create a manual backup of a specific instance
sudo -u amp amp-fhs -c "ampinstmgr BackupInstance <InstanceName>"
```

---

## Verification Commands

These must all pass before a deploy is considered healthy.

```bash
# 1. Verify the systemd service is active
systemctl is-active --quiet amp && echo "PASS: active"

# 2. Check that the service is running on the expected port 8085
ss -tlnp | grep 8085 && echo "PASS: port listening"

# 3. Test HTTP responsiveness of the backend
curl -sf http://127.0.0.1:8085/ | grep -q "AMP" && echo "PASS: backend responsive"

# 4. Confirm clean journal logs
journalctl -u amp --no-pager -n 50 | grep -c ERROR | grep -q "^0$" && echo "PASS: clean logs"
```

---

## Known Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Game server binary fails to execute (error loading shared libraries) | Missing runtime package inside `80-gaming.nix` `buildFHSEnv` | Edit `modules/80-gaming.nix`, add the missing library to `targetPkgs`, and run `node tools/build_db.js` |
| SteamCMD fails with 32-bit execution errors | 32-bit glibc wrapper is missing | Ensure `pkgsi686Linux.glibc` is present in the `multiPkgs` block of `buildFHSEnv` |
| AMP Web UI fails to load after restart | `/var/lib/amp` has incorrect file ownership | Run `sudo chown -R amp:amp /var/lib/amp` to restore file permissions |

---

## Cross-Domain Interactions

- **Depends on:** `00-core` (for system user/group registration), `10-network` (Caddy reverse proxy and firewall).
- **Used by:** Direct LAN and WAN gaming clients.
- **Shared state:** Persistent database state is stored inside `/var/lib/amp` which is fully bound to fast Tier A storage to avoid MergerFS SQLite locking blocks.