---
title:        "ADR-70: Declarative Git Infrastructure (Forgejo), PostgreSQL Migration, & Ansible Semaphore"
domain:       70
folder:       70-forge
status:       accepted
date:         2026-06-03
deciders:     [moritz]
review_after: 2027-06-03
links:
  guide:   70-forge.md
  modules:
    - Nix Files/modules/70-forge.nix
supersedes: []
---

# ADR-70: Declarative Git Infrastructure (Forgejo), PostgreSQL Migration, & Ansible Semaphore

> **We establish Forgejo as our declarative local Git forge and Ansible Semaphore as our automation dashboard, migrating Forgejo's database from SQLite to PostgreSQL with socket-based Peer authentication to prevent credential leaks and ensure database write performance.**
> This secures homelab code repositories and provides a robust, self-contained CI/CD environment.

---

## Context

**What is the problem?**
The homelab requires a private, local repository hosting engine and an automation dashboard to run Ansible playbooks and deployment scripts. The git service (Forgejo) and automation tool (Semaphore) must be fully declared in Nix and secured:
1. **Database Contention:** Storing Git metadata on SQLite leads to concurrency bottlenecks and file lock issues under high pipeline load.
2. **Credential Exposure:** Connecting tools to database backends using cleartext password credentials in configuration files introduces leak hazards in the Nix store (which is world-readable).
3. **Impermanence Integration:** State directories (git repositories, semaphore configurations) must survive system reboots while temp files are regularly cleaned.

**Why does this matter?**
A insecure database connection or corrupted git file database ruins repository history and compromises server deployments.

**Forces at play:**
- **Performance:** Fast git push/pull operations and quick pipeline runs.
- **Security:** Zero hardcoded passwords for databases in Nix.
- **Purity:** Declarative module options for all forge tools.

---

## Considered Alternatives

### Option A: Forgejo (PostgreSQL with Peer Authentication) + Semaphore ← CHOSEN

**What it is:**
We run Forgejo as the primary git server, backed by the central PostgreSQL instance.
- **Peer Sockets:** Forgejo connects to PostgreSQL via local Unix sockets (`/run/postgresql`) under the local `forgejo` system user using Peer authentication (no password needed).
- **Automation UI:** Semaphore runs via a declarative OCI podman-container systemd wrapper service to trigger local deployment tasks.
- **Persistence:** All repository storage is mapped to Tier A persistent SSD directories (`/var/lib/forgejo` and `/var/lib/semaphore`).

**Pros:**
- **Zero-Password Security:** Database access is governed exclusively by Linux system user IDs, making credential leakage impossible.
- **High Concurrency:** PostgreSQL handles dozens of concurrent commits and pipeline queries effortlessly.
- **Declarative Simplicity:** Built using native NixOS options.

**Cons:**
- Upgrading PostgreSQL requires database migrations.

---

## Decision

**We choose Option A.**

We mandate:
1. **Forgejo Database Backend:** Enforce PostgreSQL as the database engine for Forgejo.
2. **Socket Authentication:** Disable TCP database access for Forgejo; all queries must use Peer authentication on local Unix sockets.
3. **State Persistence:** Whitelist `/var/lib/forgejo` and `/var/lib/semaphore` in persistent storage bindings.

---

## Consequences

**Positive:**
- Secure, high-performance local git hosting.
- Seamless automation runs via Semaphore.
- Zero credential exposure in world-readable Nix store configs.

**Negative:**
- PostgreSQL service must be running for git pushes to succeed.

---

## Validation

- **Signal:** systemd unit checks pass, git operations over SSH/HTTPS succeed, and Semaphore can execute playbooks against local targets.
- **Review frequency:** Every 12 months.