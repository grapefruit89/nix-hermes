---
title:        "ADR-24: Global System Mode Switch (Development vs Production)"
domain:       00
folder:       00-core
status:       accepted
date:         2026-06-05
deciders:     [moritz]
review_after: 2027-06-05
links:
  guide:   20-security.md
  modules:
    - Nix Files/modules/00-core.nix
    - Nix Files/modules/20-security.nix
    - Nix Files/modules/15-firewall.nix
    - Nix Files/modules/30-storage.nix
supersedes: []
---

# ADR-24: Global System Mode Switch (Development vs Production)

> **We introduce a centralized system-wide configuration flag `my.mode` to toggle the server between `"development"` and `"production"` states, dynamically adjusting security parameters, filesystem persistence, and firewall access to streamline development while maintaining a single, declarative codebase.**

---

## Context

**What is the problem?**
Tuning a NixOS configuration for high security (e.g., zero-trust SSH, ephemeral tmpfs root, hardware-bound LUKS decryption) introduces significant complexity during the active development phase. If these features are enabled by default during development, a simple configuration error or missing file can immediately lock out the developer, leading to frustrating recovery loops.

**Why does this matter?**
A single, rigid configuration requires the administrator to manually edit multiple disjoint files (firewall, storage, security, openssh) to toggle the system's security posture, increasing the risk of configuration drift and accidental lockouts.

**Forces at play:**
- **Simplicity:** Toggling the security and persistent state of the system must be controlled by a single, obvious parameter.
- **Purity:** No imperative shell scripts or temporary workarounds should be used to bypass security measures.
- **Fail-Safety:** The fallback rescue path (Dropbear) must remain active regardless of the mode.

---

## Considered Alternatives

### Option A: Global `my.mode` Switch Option (Chosen)

**What it is:** A centralized option `my.mode` defined in core options that defaults to `"development"`. Other modules read this option to determine their defaults.

**Pros:**
- Single source of truth for the system's operational posture.
- Avoids manual configuration edit drifts across multiple modules.
- Allows convenient toggling between open development (password logins, Port 22) and production hardening (no password logins, Port 53844, tmpfs root).

**Cons:**
- Toggling the flag requires a full `nixos-rebuild switch`.

**Why chosen:** It perfectly addresses the complexity of managing and testing security features without risking lockouts.

---

### Option B: Multiple Decoupled Enable Options (Rejected)

**What it is:** Keeping separate `enable = false;` flags inside each module (`ssh-zerotrust`, `impermanence`, etc.) in the host configuration.

**Pros:**
- Fine-grained control over individual components.

**Cons:**
- Prone to developer error (forgetting to disable one flag, leading to lockout).
- Redundant declarations in host configuration files.

**Why rejected:** It makes development highly error-prone and does not prevent lockouts cleanly.

---

## Decision

**We choose Option A.**

Explicit scope: This switch controls core security policies, storage layout behaviors, and ingress firewall ports. It does not disable non-security features.

Implementation constraints:
- `my.security.dropbear-rescue` must remain enabled regardless of the mode, ensuring a permanent fallback channel.
- Setting `my.mode = "development"` must fall back to standard, non-locking defaults for OpenSSH and storage.

---

## Consequences

**Positive:**
- Switching from development to production is reduced to a single line in `configuration.nix`.
- Testing configuration changes is safer, as development mode doesn't lock out standard logins.

**Negative:**
- Developers must remember to switch the mode back to `"production"` before exposing the system to the internet.

---

## Validation

How will we know this decision is still correct?

- **Review trigger:** Re-evaluate if any other modules (e.g. monitoring, database replication) require environment-based behaviors.
- **Scheduled review:** See `review_after`.
