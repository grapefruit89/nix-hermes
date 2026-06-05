---
title:        "ADR-23: Dropbear Stage 2 Rescue SSH Daemon"
domain:       20
folder:       20-security
status:       accepted
date:         2026-06-05
deciders:     [moritz]
review_after: 2027-06-05
links:
  guide:   20-security.md
  modules:
    - Nix Files/modules/20-security.nix
    - Nix Files/modules/15-firewall.nix
supersedes: []
---

# ADR-23: Dropbear Stage 2 Rescue SSH Daemon

> **We establish a permanent, independent Dropbear rescue SSH daemon in stage-2 running on port 2222 with public-key-only authentication to safeguard remote access and prevent administrator lockouts caused by OpenSSH configuration errors or missing system-level host keys.**

---

## Context

**What is the problem?**
The main OpenSSH daemon (`sshd`) on our homelab is configured with advanced security constraints (Zero-Trust, non-standard port 53844, strict IP/TTY whitelisting). During NixOS configuration changes or system migrations (e.g. disabling impermanence, changing persist mappings), the main `sshd` is susceptible to start failures:
1. Missing host keys on a new or rebuilt root partition prevent the `sshd.service` from starting live.
2. Typos or syntax errors in OpenSSH config options or IP whitelist constraints can immediately lock out the administrator.
3. Dropbear inside `initrd` (stage-1) only runs before stage-2 boot. If there is no active LUKS container to decrypt, the boot sequence finishes instantly, making initrd SSH useless as a general rescue shell.

**Why does this matter?**
A lockout requires physical keyboard and monitor access, which is highly inconvenient for a headless server.

**Forces at play:**
- **Security:** The rescue path must not introduce weak vectors (no password logins).
- **Ingress Availability:** The service must be lightweight and have minimal dependencies to ensure it starts even when system databases, network configurations, or complex host directories are offline.
- **Purity:** The setup must remain fully declarative within NixOS.

---

## Considered Alternatives

### Option A: Out-of-band Dropbear Rescue Daemon (Stage-2) ← CHOSEN

**What it is:** A secondary systemd service that starts `dropbear` on port 2222. It uses `ExecStartPre` to copy authorized keys from the NixOS-managed SSoT directory and runs with password authentication disabled.

**Pros:**
- Complete isolation from OpenSSH's configuration.
- Minimal dependency: `pkgs.dropbear` is lightweight and highly reliable.
- Auto-generates its own host keys on startup if missing.
- Disables password authentication completely, ensuring only authorized key holders can connect.

**Cons:**
- Requires opening port 2222 in the firewall.
- Relies on a startup script to sync authorized keys for user homes.

**Why chosen:** It provides a 100% reliable out-of-band SSH entryway that survives standard OpenSSH failures and missing root partition host keys.

---

### Option B: Time-Based OpenSSH Recovery Window ← REJECTED

**What it is:** A boot-time script that temporarily modifies `/etc/ssh/sshd_config` to allow password authentication for a short duration.

**Pros:**
- None, compared to a dedicated daemon.

**Cons:**
- Highly dangerous; open-ingress window allows brute-force sweeps.
- Mutability violates NixOS declarative purity.
- Potential systemd race conditions.

**Why rejected:** This approach was explicitly deprecated as a dangerous system anti-pattern in our security guidelines.

---

## Decision

**We choose Option A.**

Explicit scope: This decision applies strictly to stage-2 system environment. It runs parallel to the main OpenSSH service.

Non-obvious implementation constraints:
- The daemon must run as root to permit user login routing.
- The firewall must dynamically open port 2222 only when this service is active.
- Password authentication must be strictly disabled.

---

## Consequences

**Positive:**
- A permanent, secure back-channel is established. If the main SSH daemon crashes, is misconfigured, or has missing keys, the administrator can log in via port 2222.
- The daemon auto-generates its host key in `/var/lib/dropbear/` on first run.

**Negative:**
- Port 2222 must be whitelisted in the nftables ruleset.

**Risks introduced:**
- Key synchronization issues if `/etc/ssh/authorized_keys.d/` is empty.
  - *Mitigation:* The system asserts that authorized keys are present before allowing zero-trust deployments.

---

## Validation

How will we know this decision is still correct?

- **Metric / signal:** Active listen status of port 2222 and successful public-key authentications logged in journald for unit `dropbear-rescue.service`.
- **Review trigger:** Re-evaluate if Dropbear is found to have unmitigated critical security vulnerabilities or if systemd transitions render foreground service supervising obsolete.
