---
title:        "ADR-00: Modernized 10-Domain Architecture, Core-DNA & Ephemeral Rollback"
domain:       00
folder:       00-core
status:       accepted
date:         2026-05-26
deciders:     [moritz]
review_after: 2027-05-26
links:
  guide:   00-core.md
  modules:
    - Nix Files/modules/00-core.nix
  supersedes: [nixhome-architecture.md, isomorphie-strategie.md, MASTER_ADR_Core_DNA.md, ADR_042_Bootloader.md]
---

# ADR-00: Modernized 10-Domain Architecture & SQLite MCP SSoT

> **We adopt the modernized 10-Domain NixOS Model as our structural layout, and establish a serverless relational SQLite database (nixos_docs.db) integrated via an MCP query server as our unified Single Source of Truth (SSoT) for documentation and code analysis.**
> This eliminates legacy multi-script sync overhead (the old Isomorphie-Strategie) and structures homelab code and guides into a cohesive, zero-drift ecosystem.

---

## Context

**What is the problem?**
In our legacy architecture, we had three primary challenges:
1. **7-Layer Bloat:** The legacy 7-layer structure (00-core to 90-policy) had overlapping classifications, causing optional packages and identity configurations to pollute critical early boot files.
2. **Synchronisation Drift:** The old *Isomorphie-Strategie* used complex custom shell scripts (`nixhome_sync_header.sh`, `nixhome_ai_refactor.sh`, `chunk_and_index.sh`) and custom NMS-Headers v2.3 to sync comments inside `.nix` files with `.md` documents. This mechanism was prone to silent execution failures and hard to maintain for a single administrator.
3. **LLM Context Overload:** The legacy directory had hundreds of unindexed files, wasting prompt tokens and degrading AI assistant performance.

**Why does this matter?**
Without structural modernization and an automated, zero-overhead indexing system, the codebase drifts from its documentation, making long-term maintenance and remote AI-assisted troubleshooting extremely slow and error-prone.

---

## Considered Alternatives

### Option A: 10-Domain Model + Relational SQLite MCP SSoT ← CHOSEN

**What it is:**
We restructure all homelab files into exactly 10 flat, clearly separated domains (00-core, 10-network, 20-security, 30-storage, 40-monitoring, 50-media, 60-apps, 70-forge, 80-gaming, 90-policy). We replace all legacy sync scripts and NMS-Headers v2.3 with the lightweight **# ---NIXMETA--- (v3.0)** header format. A centralized compiler (`tools/build_dbs.py`) recursively scans the workspace, parses frontmatter and comments, and builds a relational SQLite database (`nixos_docs.db`).

**Pros:**
- **Zero Drift:** Relational database compiles all code and docs directly, enforcing immediate integrity checks.
- **Maximum token efficiency:** The AI assistant fetches only the precise files and database fields it needs, sparing context windows.
- **Unified SSoT:** One single SQLite database acts as the single source of truth for both humans and AI models.
- **Highly Modular:** Clean separation of concerns across 10 defined domains.

**Cons:**
- Requires a database compilation step after making file changes.

---

### Option B: Legacy 7-Layer Shell Sync (NMS-Header v2.3) ← REJECTED

**Why rejected:**
High operational overhead. The shell scripts are fragile, system-dependent, and do not provide a structured database schema that an AI assistant can query dynamically.

---

## Decision

**We choose Option A.**

We implement a modernized layout with the following constraints:
1. **Directory Structure:** Flat, synchronized domain folders across `ADR`, `Guides`, and `Nix Files/modules`.
2. **Metadata Standard:** Standardize on **NIXMETA v3.0** commenting formats.
3. **Relational Compiler:** Use `tools/build_dbs.py` to build `nixos_docs.db` after any changes.
4. **LLM Access:** Enable the `nixos_sqlite` MCP server to interact with the relational cache.

---

## Consequences

**Positive:**
- **Instant Search:** Full-text and metadata searching takes milliseconds.
- **Absolute KISS:** Replaced hundreds of lines of fragile bash scripts with a single Python compiler.
- **Flawless Organization:** 10 clear domains make file placement unambiguous.

**Negative:**
- Changes in the workspace are not immediately visible to the MCP server until database compilation is run.

---

## Validation

- **Signal:** Python compiler exits with code 0 and updates the database size on `nixos_docs.db`.
- **Scheduled review:** Review every 12 months to ensure no domain drift occurs.

================================================================================

# ADR-00-DNA: NixOS Core-DNA & Architectural Laws

> **We establish the Core-DNA and architectural laws of our NixOS homelab. This includes adopting Haumea-driven hierarchical module loading, strict hardware/core layer separation, absolute system control via deliberate `lib.mkForce` usage, and aggressive scheduling guarantees to prevent system freezes during background builds.**

---

## Context

**What is the problem?**
As a homelab evolves, it is highly prone to "Configuration Drift" and "System-Rot". When hardware boundaries, configuration parameters, and user profiles are mixed within core operating system files:
1. Re-building the system on a new host or recovering from bare metal becomes a tedious, hour-long troubleshooting exercise.
2. Silent resource depletion (such as Nix-Daemon consuming all CPU/IO cycles during builds) causes severe host freezing and interface lag.
3. Upstream module defaults can override custom optimizations silently, leading to degraded performance or insecure fallback policies.

**Why does this matter?**
Achieving "Aviation-Grade" reliability requires that the foundational OS layer is completely predictable, reproducible, and robust against resource starvation and configuration sprawl.

---

## Considered Alternatives

### Option A: Haumea-Driven Decoupled Core-DNA ← CHOSEN

**What it is:**
We modularize the entire system into 10 flat, clearly separated domains. The configuration loads recursively and hierarchically using **Haumea** to avoid explicit `imports = [ ... ]` block sprawl. Core system modules are strictly platform-agnostic. All hardware parameters (kernel modules like `i915`, CPU specifics) are kept in the hardware configuration. We configure systemd-resilience restart policies (`always`, `OOMScoreAdjust = -1000`) and Nix-Daemon build limits natively in `00-core`.

**Pros:**
- **Modular Autonomy:** Haumea dynamically structures files, preventing missing imports.
- **Hardware Portability:** Moving the entire operating system configuration to a new computer takes minutes because Core contains zero hardware dependencies.
- **System Stability:** Restricting build priorities (`nix.daemonCPUSchedPolicy = "idle"`, `nix.daemonIOSchedPriority = 7`) ensures the system remains fully responsive even during intensive rebuilds.
- **Explicit Override Purity:** The Flake has the final word on options using selective `lib.mkForce` directives.

**Cons:**
- High abstraction requires thorough documentation of variables.

---

### Option B: Monolithic configuration.nix & Manual Imports ← REJECTED

**Why rejected:**
This is a major homelab anti-pattern. Monolithic configurations are unreadable, impossible to test incrementally, and inevitably lead to severe configuration drift and untrackable dependencies across host profiles.

---

## Decision

**We choose Option A.**

We implement our Core-DNA with the following structural rules:
1. **Haumea Modularity:** Automate system module loading dynamically.
2. **Platform Separation:** Keep the core layer hardware-agnostic. All drivers, boot kernel modules, and device parameters belong strictly in hardware configuration.
3. **Daemon Tuning:** Restrict build limits dynamically based on RAM capacity (ZRAM limits, core scheduling constraints).
4. **Resilience Policy:** Enforce `always` systemd restart bounds and aggressive OOM limits for essential services.

---

## Consequences

**Positive:**
- **Zero Configuration Drift:** The system is 100% reproducible and stateless.
- **Immediate Host Recovery:** MTTR (Mean Time to Recovery) drops to minutes.
- **Silky Smooth Operation:** Building packages does not freeze user-facing apps.

**Negative:**
- Requires clean separation discipline from the administrator when adding packages.

---

## Validation

- **Signal:** Rebuild exits with code 0 and CPU scheduler priorities confirm `nix-daemon` is constrained under the `idle` group.
- **Review frequency:** Every 12 months.

================================================================================

# ADR-00-IMPERMANENCE: Ephemeral Stateless Root Rollback

> **We establish a strict "stateless root" paradigm for our homeserver, where the root directory (`/`) is mounted on ephemeral memory (`tmpfs`) or automatically wiped and rolled back to a blank subvolume on every system boot.**
> This guarantees total immunity against operational configuration drift, locks out malicious boot-level persistent modifications, and enforces absolute declarative reproducibility.

---

## Context

**What is the problem?**
Standard Linux and NixOS configurations accumulate massive amounts of runtime state, temporary files, logs, and untracked drifts inside the root partition (`/`) over months of operational upgrades. In a classic "mutable" state homelab, drive corruption, failed package installations, or malicious intrusions can silently compromise system integrity.

**Why does this matter?**
Without a stateless bootstrap, the system's runtime state can slowly deviate from its git-declared Nix configurations. We want a server that is fully "disposable" at the operating system level, ensuring that if we delete or rebuild our state partitions, the system boots into an identical, clean state.

**Forces at play:**
- **System Cleanliness:** Complete elimination of configuration drift and filesystem rot.
- **Security:** Malicious modifications to root filesystems are erased instantly upon reboot.
- **State Integrity:** Real user state (databases, media assets, documents) must be robustly segregated and protected.

---

## Considered Alternatives

### 1. Ephemeral Root on tmpfs / Blank Btrfs Rollback ← CHOSEN

We mount `/` on a volatile `tmpfs` partition in RAM (or run a Btrfs pre-mount hook that formats/restores `/` to a pristine blank snapshot on every boot):
* **Purity:** Everything under `/` is ephemeral.
* **Declarative persistence:** Only explicitly declared directories (like `/persist` for system states or `/data` for databases) are mounted on persistent storage.

```
[Booting NixOS]
      │
      ▼
[Initrd pre-mount] ──► Wipes and restores "/" to empty state
      │
      ├─► Mounts Ephemeral "/" in RAM (tmpfs)
      ├─► Bind-mounts "/persist/etc/ssh" to "/etc/ssh"
      └─► Bind-mounts "/data/state/postgres" to "/var/lib/postgresql"
```

* **Pros:** Complete structural purity. Any file created outside of `/persist` or `/data` vanishes instantly upon reboot.
* **Cons:** Misconfiguring a persistent directory bind-mount can cause quiet loss of application state upon reboot.

---

### 2. Standard Mutable Root Partition (ext4) ← REJECTED

**Why rejected:** Suffers from long-term configuration drift, cache bloat, and manual package residue.

---

## Decision

**We accept Option 1.**

We implement stateless rollback with the following rules:
1. **Zero-State Root:** The root `/` is mounted on an ephemeral RAM partition (`tmpfs`) or rolled back to an empty Btrfs subvolume on boot.
2. **Strict Persistence whitelist:**
   * `/etc/ssh/ssh_host_ed25519_key` (Server identity key)
   * `/var/lib/sops-nix/key.txt` (SOPS age key)
   * `/var/lib/` state directories for persistent databases and services.
3. **Log isolation:** System logs are maintained on `/var/log` mapped to memory to prevent disk bloat.