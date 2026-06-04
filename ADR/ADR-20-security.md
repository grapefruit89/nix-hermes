---
title:        "ADR-20: Sovereign Identity via Hardware-USB Identity Anchor"
domain:       20
folder:       20-security
status:       accepted
date:         2026-05-25
deciders:     [moritz]
review_after: 2027-05-25
links:
  guide:   20-security.md
  modules:
    - Nix Files/modules/20-security.nix
  supersedes: []
---

# ADR-20: Sovereign Identity via Host SSH-to-Age Key Bootstrap

> **We convert the host's existing SSH private key to an age-compatible master key (`/var/lib/sops-nix/key.txt`) as the primary stateless identity bootstrap.**
> This ensures that an impermanent, stateless NixOS host can verify its identity and securely unlock local SOPS secrets without requiring interactive passphrases on boot or relying on external USB drives where inapplicable.

---

## Context

**What is the problem?**
In an impermanent (stateless) system, the OS starts from a clean root on every boot. This architecture is highly secure and predictable, but it introduces a major bootstrapping challenge: How does the server verify its identity and access encrypted resources (such as SOPS secrets and Restic backup keys) without manual passphrase entry on every boot?

If we hardcode a decryption key in the Nix store, it is globally readable. If we keep keys on unencrypted system drives, a physical drive theft exposes the entire key material.

Standard `sops` 3.x no longer supports `SOPS_AGE_SSH_PRIVATE_KEY_FILE` directly, meaning a host SSH private key cannot be read natively as an age key at runtime without pre-boot conversion.

**Why does this matter?**
Without a secure, automated boot-time identity verification mechanism, we either lose unattended reboot capability (requiring manual SSH typing on every boot) or compromise our security posture by keeping secrets in plaintext on internal system drives.

**Forces at play:**
- **Security:** Keys must never reside in plaintext on internal drives or in the public nix-store.
- **Automation:** Reboots must be zero-touch / unattended.
- **Physical Security:** Drive theft must not expose decrypted secrets.
- **KISS Compliance:** The mechanism must rely on standard Linux crypt-infrastructure and standard tools like `ssh-to-age`.

---

## Considered Alternatives

### Option A: Host SSH-to-Age Key Conversion with Persistent Directory Mapping ← CHOSEN

**What it is:**
We utilize the host's existing SSH private key (`/etc/ssh/ssh_host_ed25519_key`) and convert it to a standard age key file (`/var/lib/sops-nix/key.txt`) using the `ssh-to-age` utility. This converted age key is kept in `/var/lib/sops-nix/`, which is persistently mapped across boots (using our storage persistence layer). Sops-nix services load their secrets natively from this age key.

**Pros:**
- **Zero-Touch Boot:** Boot is fully automated and does not require manual entry of passwords or physical insertion of USB keys.
- **Simplicity:** Leverages the existing cryptographically secure host SSH key, eliminating external hardware dependency.
- **Stateless Integration:** Fits perfectly into the impermanent model by storing the key in the persistent storage path `/var/lib/sops-nix/`.

**Cons:**
- Relies on the security of the persistent storage partition.

**Why chosen:** It provides the most reliable and KISS-compliant automated bootstrap mechanism for stateless systems, using proven cryptographic components already present on the server.

### Option B: Physical USB Identity Anchor bound to TPM2.0 ← REJECTED

**What it is:** A physical USB stick formatted with LUKS2, bound to the local motherboard TPM2.0 chip, which is mounted on boot to copy keys and unmounted immediately.

**Why rejected:** Adds significant physical hardware dependency (USB ports, risk of USB stick wear/theft/failure) and high complexity (udev rules, systemd mount hooks) for minimal security gain over persistent directory isolation.

---

## Decision

**We choose Option A.**

We implement a host-key based bootstrapping system with the following constraints:
1. **Key Conversion:** The server's persistent `/etc/ssh/ssh_host_ed25519_key` is converted using `ssh-to-age` and saved to `/var/lib/sops-nix/key.txt`.
2. **Access Control:** The age key file is restricted to owner `root` with `0600` permissions.
3. **SOPS Integration:** All systemd services that require secrets natively reference this key path via `sops-nix` integrations.

---

## Consequences

**Positive:**
- **Stateless Bootstrap:** Impermanent setups can securely boot and decrypt secrets without manual key entry.
- **Simplified Deployment:** No external physical dependencies or complex custom mount hooks.
- **Clean Store:** Secrets remain fully encrypted in Git and are decrypted only in memory at runtime.

**Negative:**
- If the persistent state partition containing `/var/lib/sops-nix/` is corrupted, manual recovery of the keys using the master backup passphrase is required.

---

## Validation

- **Signal:** systemd units using `sops-nix` secrets (like Traefik, Caddy, or Valkey) load successfully.
- **Scheduled review:** See `review_after` in frontmatter.