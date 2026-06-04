---
title:        "ADR-21: Ingress and SSH Access Control Hardening"
domain:       20
folder:       20-security
status:       accepted
date:         2026-05-26
deciders:     [moritz]
review_after: 2027-05-26
links:
  guide:   20-security.md
  modules:
    - Nix Files/modules/20-security.nix
    - Nix Files/modules/50-media.nix
supersedes: []
---

# ADR-21: Ingress and SSH Access Control Hardening

> **We secure system SSH access by shifting to high-port 53844, enforcing strict TTY whitelisting for trusted subnet addresses in sshd_config, and implementing User-Agent-based smart gateways that allow native media applications to bypass reverse-proxy authentication while forcing web browsers through double security checks.**
> This drastically limits operational attack vectors on our homelab.

---

## Context

**What is the problem?**
A headless production server exposed to local network ranges and Tailscale is susceptible to automated script sweeps, unauthorized local users, or brute-force attempts. We need:
1. Strong perimeter isolation for SSH: preventing standard sweeps on Port 22 and enforcing strict terminal whitelisting so that only authorized, trusted local/VPN ranges can start a TTY shell.
2. Usable security for media services (e.g. Jellyfin): protecting browser access from the internet with a robust authentication barrier (like BasicAuth or OIDC) while avoiding usability lockouts on native clients (Smart TVs, Mobile apps, Fire TV) that cannot natively parse reverse proxy authentications.

**Why does this matter?**
Leaving Port 22 open leads to massive scan noise and brute-force risk. Furthermore, native media player applications do not support standard web-based OAuth/OIDC/BasicAuth gateways, leading to a direct clash between high security and basic homelab usability.

**Forces at play:**
- **Security:** Ingress protocols must be whitelisted only for trusted networks.
- **Usability:** Native media player clients must work seamlessly.
- **Isolation:** Unauthorized clients must not reach internal services.

---

## Considered Alternatives

### 1. SSH Hardening (Port 53844 + TTY IP Whitelisting)

We choose to move SSH to high-port **53844** and disable generic TTY execution using `Match Address` whitelisting inside `sshd_config`:
```nix
Match Address 127.0.0.1,::1,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12,100.64.0.0/10
  PermitTTY yes
Match All
  PermitTTY no
```
* **Pros:** Completely prevents any client outside the whitelisted subnets (local LAN or Tailscale) from executing interactive shells even if they somehow obtain matching credentials.
* **Cons:** Requires mapping custom ports for remote execution.

---

### 2. Smart Gateway Authentication Bypass (User-Agent Sniffing)

For media stack applications (Jellyfin, Lidarr, Radarr), we implement smart gateway rules in our reverse proxy (Caddy/Traefik).
* **Browser Clients:** Web browsers (Chrome, Firefox, Safari) matching standard headers are forced to authenticate at the gateway layer (e.g. OIDC or BasicAuth) prior to reaching the application's login screen (providing double defense).
* **Native Apps:** Native clients (mobile apps, TV players) matching whitelisted User-Agent prefixes (e.g. `Jellyfin*`, `JMP*`) are routed directly to the application's native login screen, bypassing the proxy barrier.

| Ingress Client | User-Agent | Gateway Auth? | Application Login? |
|----------------|------------|---------------|-------------------|
| Web Browser    | Mozilla/*  | ✅ Enforced   | ✅ Enforced (Double) |
| Native TV App  | Jellyfin*  | ❌ Bypassed   | ✅ Enforced       |

* **Pros:** High security for the vulnerable web browser access path without breaking native media player app integrations.
* **Cons:** User-Agent headers can theoretically be spoofed, but spoofers must still pass the application's internal multi-factor/password checks.

---

## Decision

**We accept both strategies.**
1. **SSHD Hardening:** Shift to port 53844 and enforce CIDR-based TTY whitelisting for all internal networks.
2. **Smart Gateway Ingress:** Whitelist native media player clients by matching their User-Agent headers at the reverse proxy layer.

---

## Consequences

**Positive:**
* Complete defense against port scanners on the standard SSH port.
* Unauthorized external entities hitting our media domains via web browsers are blocked at the proxy gateway.
* Fully automated reboots and native client logins work perfectly without manual administrator intervention.

**Negative:**
* Native client User-Agents must be monitored and whitelisted in the proxy gateway configuration if developers change application naming schemes.
