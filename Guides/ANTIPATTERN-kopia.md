---
title: "Antipattern: Kopia Backup Engine on Impermanent NixOS"
status: antipattern
tags: [antipattern, verboten, storage, backup]
---

# 📛 ANTIPATTERN: Kopia Backup Engine on Impermanent NixOS

In this guide, we document why utilizing the Kopia backup tool represents an antipattern for our specific homelab system design and architecture.

### The Antipattern Defined

Running Kopia for server backups on a stateless NixOS node with an ephemeral root (`tmpfs` on `/`) is considered an antipattern. It violates the core system design principles of **Declarative Purity** and **State Separation**.

### Detailed Analysis & Architectural Mismatch

#### 1. Lack of Declarative NixOS Integration
- **The Ideal**: Every service, user, timer, and configuration detail is fully declared in our Nix files.
- **The Kopia Reality**: There is no official NixOS module for Kopia. Deploying Kopia would require manual script configuration, systemd service overrides, and key injection, adding significant maintenance overhead.

#### 2. Statefulness and Impermanence Conflict
- **The Ideal**: The root filesystem is stateless and can be wiped on reboot without data loss. Only declared paths are bound to `/persist`.
- **The Kopia Reality**: Kopia relies on local database caches and connection states stored by default in `~/.config/kopia/` or `/root/.config/kopia/`. If these config files are lost during a reboot:
  1. The server loses its connection profile to the remote repository.
  2. Next backup jobs fail unless manual reconnect CLI commands are run.
  3. Storing config parameters inside `/persist` requires complex bind-mounting of user config folders, causing state clutter.

#### 3. Reliability and Corruption Issues
- Upstream community reports note repository index corruption issues when Kopia repositories run out of disk space or experience unexpected interrupted network connections.
- Restic utilizes a simpler, content-addressable repository format that is extremely stable, predictable, and has proven recovery paths under disk exhaustion.

### Correct Pattern: Restic with Prepare/Cleanup Hooks

Instead of Kopia, we use **Restic** combined with systemd service cycling:
- **Declarative**: Configured entirely via the standard `services.restic.backups` module.
- **Stateless**: Credentials and repository connections are resolved dynamically via SOPS files and environment variables, leaving zero configuration footprint in `/root` or `/home`.
- **Consistent**: Uses `backupPrepareCommand` and `backupCleanupCommand` to stop and start databases and web apps, ensuring database snapshots are fully consistent.
