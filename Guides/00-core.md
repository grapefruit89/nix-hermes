---
title: "Core Domain Guide: System Performance, Tuning & DB Compilation"
domain: 00
folder: 00-core
status: active
complexity: 4
last_reviewed: 2026-05-26
links:
  adr:     ADR-00-core.md
  modules:
    - path: Nix Files/modules/00-core.nix
---

# Core Domain Guide: System Performance, Tuning & DB Compilation

> **Operational guide for managing the core system parameters of the Fujitsu Q958 homelab, including boot safeguards, kernel-slimming diagnostics, ZRAM monitoring, and active SSoT SQLite database building.**
> Keeps the fundamental OS stable, secure, and optimized for maximum available RAM.

---

## Prerequisites

Before modifying core parameters, ensure:
- [x] Host has at least 4GB of physical RAM (optimizations dynamically adapt up to 16GB).
- [x] Host processor is an Intel CPU (Gen9+ i3-9100) for Intel Media Driver matching.
- [x] Node.js is installed locally on the administrator client for compiler execution.

---

## How It Works

```
[Markdown Notes / Nix Configs] ──(node tools/build_db.js)──► [import.sql]
                                                                  │
                                                           (sqlite3 import)
                                                                  ▼
[LLM / AI Assistant (Antigravity)] ◄──(nixos_sqlite MCP)─── [nixos_docs.db]
```

1. **Boot Safeguard:** Limits systemd-boot generation entries to `5` to completely prevent EFI System Partition (ESP) overflows on tight 96MB partitions.
2. **Kernel Slimming:** Blacklists sound, bluetooth, and legacy wireless modules, saving ~300MB of resident RAM.
3. **ZRAM swapping:** Establishes compressed swap space directly in volatile memory, utilizing `zstd` compression at a custom swappiness weighting of `180` to minimize disk read/write wear.
4. **Relational compilation:** Gathers all frontmatter and metadata via `tools/build_db.js`, generating `import.sql` to re-compile the active SQL SSoT.

---

## Operational Procedures

### Compiling and Rebuilding the SSoT SQLite Database

Execute these commands in PowerShell inside `C:\Users\morit\Documents\Obsidian_Main\NixOS\` whenever a Nix configuration or Markdown note is added, updated, or removed:

```powershell
# 1. Compile the active database SQL schema and data
node tools/build_db.js

# 2. Re-import and fill the SQLite database nixos_docs.db
Get-Content import.sql -Raw | sqlite3 nixos_docs.db

# 3. Clean up the temporary SQL script
Remove-Item import.sql
```

### Verifying Kernel Slimming and RAM Savings

After applying `kernel-slim.nix` configurations, verify that unneeded modules are successfully unloaded and RAM is cleared:

```bash
# 1. Verify that blacklisted modules (e.g. bluetooth) are NOT loaded
lsmod | grep -i blue

# 2. Check current available RAM (compare against prior baseline)
free -h

# 3. View active hardware GPU rendering layers (vainfo test)
vainfo
```

### Monitoring ZRAM Compression and Swapping

```bash
# 1. View ZRAM device state and compression ratio
zramctl

# 2. Verify active swap boundaries and priorities
cat /proc/swaps

# 3. Check kernel swappiness policy
sysctl vm.swappiness
```

---

## Verification Commands

Run these core health checks to verify bootstrap stability:

```bash
# 1. Check systemd-boot generation count
nixos-rebuild list-generations

# 2. Verify Nix store automatic optimization parameter
nix-store --show-receiver-stats 2>/dev/null || echo "Store active"

# 3. Verify nix daemon schedule policy is set to idle
ps -eo comm,ni | grep nix-daemon
```

---

## Known Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Boot partition full / Rebuild fails | More than 5 generations accumulated manually | Run garbage collection: `nix-collect-garbage -d` |
| GPU VA-API hardware offloading fails | Intel media runtime package missing or corrupt | Check `intel-media-driver` status in Nix Store |
| DB compile script throws node module error | Node runtime missing packages | Run `npm install` inside the project root |
| ZRAM swap not active | Swappiness kernel parameters overridden | Verify sysctl properties in active `configuration.nix` |