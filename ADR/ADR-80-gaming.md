---
title:        "ADR-80: Decoupled Game Server Management via Native FHS & AMP"
domain:       80
folder:       80-gaming
status:       accepted
date:         2026-05-27
deciders:     [moritz]
review_after: 2026-11-27
links:
  guide:   80-gaming.md
  modules:
    - modules/80-gaming.nix
  supersedes: []
---

# ADR-80: Decoupled Game Server Management via Native FHS & AMP

> **We implement AMP (Application Management Panel) running inside a customized, native Filesystem Hierarchy Standard (FHS) systemd sandbox (`buildFHSEnv`) for all game server instances.**
> This avoids the massive performance overhead, disk space usage, and networking complexity of running multiple separate Docker containers or unpatched binary scripts.

---

## Context

**What is the problem?**
Deploying modern game servers (Minecraft, SteamCMD-based servers, Factorio, etc.) on NixOS is historically challenging because:
1. **Dynamic Linker Issues:** Game binaries compiled for standard Linux distributions expect standard paths (e.g., `/lib/ld-linux-x86-64.so.2` and `/usr/lib/libstdc++.so.6`), which do not exist on NixOS.
2. **Dynamic Updates:** Game servers frequently download unpatched updates, mods, or plugins directly at runtime, making them incompatible with NixOS's read-only, declarative Nix store model.
3. **Resource Overhead:** Running game servers inside Docker containers introduces substantial I/O, virtualization, and memory overhead, which is critical on our 16GB RAM Fujitsu Q958 homelab hardware.

**Why does this matter?**
A fragile setup with arbitrary scripts results in frequent service failures upon game updates, security vulnerabilities due to root privileges, and high memory leaks.

**Forces at play:**
- **Performance:** Low memory footprint and native disk performance are critical for high-tickrate game servers.
- **Maintainability:** Operators need a simple web panel to provision, update, and manage instances without ssh.
- **Security:** Game server processes must be isolated from host secrets and private keys.

---

## Considered Alternatives

### Option A: Native FHS Sandbox & AMP Web UI ← CHOSEN

**What it is:**
Deploy the AMP Game Server Management Panel inside a single, dedicated systemd service running within an FHS sandbox package (`buildFHSEnv`) with all target runtimes mapped natively.

**Pros:**
- Direct, bare-metal CPU and disk I/O performance.
- Mod and game server dynamic updates work seamlessly out of the box because the sandbox mimics a standard Linux system.
- Hardened systemd namespace isolation (isolation of the `amp` user, lockouts of `/persist` and secrets).

**Cons:**
- Requires bootstrapping the first instance (`ampinstmgr`) manually via the FHS shell.

**Why chosen:** Bare-metal execution efficiency coupled with sandboxed isolation is the absolute standard for our low-power homelab server environment.

---

### Option B: Docker Containers (Pterodactyl or manual compose) ← REJECTED

**What it is:**
Run a full Pterodactyl panel or manual docker-compose stacks for each game server.

**Pros:**
- Complete kernel-level namespace separation between different game servers.

**Cons:**
- Heavy RAM usage (each node daemon, panel, and Redis/PostgreSQL container consumes ~1-2GB before games even boot).
- Very complex virtual network routing and bridge firewall rules that conflict with our Zero-Trust Tailscale setups.

---

## Decision

**We choose Option A.**

Explicit scope: This decision applies strictly to production game server instances running on the `q958` server. It does not apply to lightweight, read-only system packages.

Implementation constraints:
- **SSD Storage Tier A:** The database and instance files must reside strictly on Tier A fast storage `/var/lib/amp` to guarantee instant load times and prevent MergerFS database locking errors.
- **SSO Bypass Ingress:** The proxy `amp.m7c5.de` utilizes Caddy standard security headers but does NOT force standard SSO auth, as AMP manages its own fine-grained, secure multi-user role-based access control (RBAC).

---

## Consequences

**Positive:**
- Extremely fast game initialization and low idle resource footprint.
- Seamless SteamCMD automation.
- One-click backups and systemd-level process recovery.

**Negative:**
- Manual bootstrap command execution is required upon clean reinstallations.

---

## Validation

- **Review trigger:** Re-evaluate this ADR if unpatched game servers fail to execute due to missing 32-bit glibc or dynamic linking libraries inside the FHS environment.
- **Scheduled review:** November 2026.