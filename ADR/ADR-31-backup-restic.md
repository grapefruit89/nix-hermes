---
title:        "ADR-31: Deciding on Backup Strategy - Restic vs Kopia"
domain:       30
folder:       30-storage
status:       accepted
date:         2026-06-02
deciders:     [moritz]
review_after: 2027-06-02
links:
  guide:   ANTIPATTERNS.md
  modules:
    - Nix Files/modules/30-storage.nix
  supersedes: []
---

# ADR-31: Deciding on Backup Strategy - Restic vs Kopia

> **We establish Restic as the primary backup management utility for our state and database snapshots (Tier A). We explicitly reject Kopia for our system configuration due to its lack of a declarative NixOS module, the generation of stateful configuration directories under the home folder, and risks of repository corruption on full storage conditions. We declare backup prepare and cleanup commands in Restic to gracefully cycle databases and dependent services, guaranteeing transaction-safe snapshots.**

---

## Context

**What is the problem?**
We need a robust, offsite backup mechanism for our stateless, impermanent (tmpfs on `/`) server. High-priority states like PostgreSQL databases, Vaultwarden logins, and Paperless files must be backed up securely to S3 storage. We require a tool that aligns with:
1. **Stateless / Ephemeral Philosophy:** Any configuration must be fully declared in Nix and must not rely on files generated interactively in `/home` or `/root`.
2. **Database Consistency:** Database files must be stopped or locked before backup starts to prevent backing up corrupt/half-written state.
3. **Ecosystem Stability:** The backup engine must be robust against repository corruption during disk pressure.

---

## Considered Alternatives

### Option A: Restic ← CHOSEN

**What it is:**
A mature, command-line-driven backup tool that is fully integrated into the NixOS module ecosystem via `services.restic.backups`.

**Pros:**
- **Excellent NixOS Module:** We can configure credentials, repositories, timers, hooks, and prune policies entirely in Nix.
- **Zero local configuration state:** Running backups does not write configuration files to local directories (e.g. `~/.config`), which fits the impermanent model.
- **Transaction Safety:** Supports `backupPrepareCommand` and `backupCleanupCommand` to stop and start databases automatically.
- **Stable and tested:** Extensive community validation and robust repository formats.

**Cons:**
- Lacks a native web interface (though there are third-party wrappers, which we do not need for a headless server).

---

### Option B: Kopia ← REJECTED

**What it is:**
A fast, modern backup engine featuring compression and client-side encryption.

**Why rejected:**
- **Stateful configuration:** Kopia requires local connection files under `~/.config/kopia` to connect to repositories. This is highly problematic on impermanent systems where `/` is wiped on reboot.
- **Ecosystem Gaps:** Kopia has no official declarative NixOS module. It would require manual systemd unit creations or custom wrapper scripts.
- **Repo Corruption Risks:** Community discussions have flagged repository indexing issues and corruption risks when Kopia repositories run out of disk space.

---

## Decision

**We choose Option A.**

We will:
1. Continue utilizing **Restic** as our exclusive backup tool.
2. Hard-code `backupPrepareCommand` and `backupCleanupCommand` hooks in `30-storage.nix` to cycle postgresql, n8n, and paperless services.
3. Classify Kopia as an antipattern for impermanent NixOS platforms.

---

## Validation

- **Signal:** Restic executes automated systemd-timers, and services stop and restart cleanly during the backup window.
- **Review frequency:** Every 12 months.
