---
title:        "ADR-90: Zero-Trust AI Agent Sandboxing & bubblewrap Policies (jailed-agents)"
domain:       90
folder:       90-policy
status:       accepted
date:         2026-05-26
deciders:     [moritz]
review_after: 2027-05-26
links:
  guide:   90-policy.md
  modules:
    - Nix Files/modules/90-policy.nix
  supersedes: []
---

# ADR-90: Zero-Trust AI Agent Sandboxing & bubblewrap Policies (jailed-agents)

> **We establish a zero-trust AI execution policy utilizing bubblewrap-based sandboxing (jailed-agents) for running autonomous LLM coding agents. This isolates AI systems from critical host assets (such as SSH host keys, Restic backup passwords, and sops-nix age decryption keys), protecting the integrity and confidentiality of the homelab.**

---

## Context

**What is the problem?**
As autonomous LLM coding agents become highly integrated into our development workflow, running them directly on the host machine poses a severe security risk:
1. **Accidental Damage:** An agent executing complex build scripts could accidentally trigger file deletions, directory overwrites, or ZFS dataset drops.
2. **Data Exfiltration:** If an LLM agent is compromised or displays rogue behavior, it could access, read, and exfiltrate private SSH keys, SOPS secrets, database state, or GID 169 media files to external APIs.
3. **Configuration Drift:** Agents making unmanaged changes directly to host folders bypass the declarative Git-based NixOS SSoT model, violating our system purity mandates.

**Why does this matter?**
A premium sovereign homelab must maintain absolute security boundaries. AI helpers should operate strictly in a "least privilege" sandboxed container, ensuring they can execute coding tasks without risking host secrets or system stability.

---

## Considered Alternatives

### Option A: bubblewrap-based isolation (jailed-agents) ← CHOSEN

**What it is:**
We run coding agents inside a restricted bubblewrap (`bwrap`) container managed by the `jail.nix` library. The container only mounts the specific project directory as read-write, hides all `/persist` secrets and `/etc/ssh` keys, and restricts shell tools to a declared whitelist (e.g. `git`, `nix`, `ripgrep`).

**Pros:**
- **Zero Host Abstraction overhead:** Runs natively on the Linux kernel using standard namespaces.
- **Strict Isolation:** Completely blocks access to `/var/lib/sops-nix/key.txt` and private SSH credentials.
- **SSoT Alignment:** Prevents configuration drift by keeping edits isolated to the designated project folder.

**Cons:**
- Requires configuring and maintaining bubblewrap bind-mount paths for any custom compilers or Nix store packages the agent needs to access.

---

### Option B: Traditional Docker/Podman Containers ← REJECTED

**What it is:**
Running the LLM agents inside standard Docker or Podman containers.

**Why rejected:**
High friction and package duplication. Docker containers lack native, low-overhead integration with the Nix store (`/nix/store/`). If the agent needs to run `nix-instantiate` or evaluate local system modules, we would have to map the entire Nix store inside the container or rebuild packages from scratch, leading to extreme performance and maintainability overhead.

---

## Decision

**We choose Option A.**

We declare bubblewrap-based sandboxing via `jailed-agents` as our standard AI safety policy. 
1. **Scope:** Applies to all autonomous coding agents, LLM tool-calling daemons, and automated shell-executors running in our environment.
2. **Hard Isolation Rules:** No agent-shell shall be allowed to bind `/var/lib/sops-nix/` or `/persist/etc/ssh/`.
3. **Execution Context:** The `mcp-nixos` server shall act as the primary documentation interface to eliminate hallucination vectors without granting agents raw filesystem access to global configs.

---

## Consequences

**Positive:**
- **Absolute Safety:** The server's master secrets, database state, and encryption keys are fully protected from rogue AI execution.
- **Purity Enforcement:** Coder edits are isolated to Git-tracked project folders.
- **Auditable Scopes:** Easily track exactly which directories and tools are exposed to the bubblewrap cage.

**Negative:**
- Minor configuration overhead in customizing `devShells` to bind necessary Nix store compilers for complex agent tasks.

---

## Validation

- **Signal:** The bubblewrap shell successfully blocks attempts by the agent to run `cat /var/lib/sops-nix/key.txt` or read private SSH identities.
- **Review frequency:** Every 12 months.