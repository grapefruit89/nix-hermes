---
title:        "ADR-40: Decentralized Dynamic Observability, Loopback SSH Sockets & CrowdSec Integration"
domain:       40-monitoring
folder:       40-monitoring
status:       accepted
date:         2026-06-05
deciders:     [moritz, antigravity]
review_after: 2027-06-05
links:
  guide:   40-observability.md
  modules:
    - Nix Files/modules/40-observability.nix
    - Nix Files/modules/15-firewall.nix
supersedes: []
---

# ADR-40: Decentralized Dynamic Observability, Loopback SSH Sockets & CrowdSec Integration

> **We consolidate all observability (Gatus, Vector/Loki/Grafana logging, and CrowdSec IDS) into a unified domain module and decouple endpoint configs from static Nix code by loading Gatus endpoints dynamically at runtime, prioritizing Unix domain socket loopbacks for checks.**

---

## Context

**What is the problem?**
- In our previous configuration, Gatus monitoring had static health check endpoints hardcoded in the Nix files. Changing monitored endpoints required full NixOS rebuilds, which is slow and introduces friction.
- Checking local system sockets (like PostgreSQL, Valkey, and Forgejo) typically requires exposing their respective TCP ports, which increases the server's network attack surface.
- CrowdSec dynamic bouncer sets were not statically defined in the nftables firewall, leading to potential race conditions during firewall reloads where all bans are temporarily lifted before the bouncer can re-inject them.
- Grafana's security key was hardcoded in Nix configurations, leaving it readable in the world-readable `/nix/store`.

**Why does this matter?**
Hardcoding endpoints and secrets hurts security and flexibility. Leaving the CrowdSec sets undefined in static firewall rules compromises security during rebuilds.

**Forces at play:**
- **Security:** Secret keys and private databases must not leak into the Nix store. Network exposure of internal services should be minimal.
- **Maintainability:** AI agents and administrators should be able to update endpoints without running a full `nixos-rebuild switch`.
- **Performance:** Local UDS monitoring should have minimal latency and not require network interface roundtrips.

---

## Considered Alternatives

### Option A: Consolidated Observability Module with SSH Loopback Sockets & Declarative nftables Sets ← CHOSEN
Consolidate all monitoring, VLG logging, and CrowdSec into `40-observability.nix`. Move Gatus endpoints to a runtime-loaded `/etc/gatus/endpoints.yaml`. Use an OpenSSH wrapper that restricts the `monitoring` user to check scripts, query local databases over Unix domain sockets, declare CrowdSec sets statically in `15-firewall.nix`, and load Grafana secrets via `EnvironmentFile`.

**Pros:**
- Endpoints can be updated instantly by editing `endpoints.yaml` and restarting Gatus.
- Services (PostgreSQL, Valkey, Forgejo) only need local UDS sockets, reducing TCP exposure.
- Safe secret management using `/var/lib/secrets/` and `EnvironmentFile`.
- Firewall rules are statically declared, ensuring CrowdSec bans are active immediately upon boot.

**Cons:**
- SSH loopback requires managing an SSH keypair for Gatus local check execution.

---

### Option B: Hardcoded Nix Modules with TCP Port Exposure ← REJECTED
Keep Gatus endpoints in Nix, expose database TCP ports for monitoring, and let the CrowdSec bouncer create dynamic nftables rules at runtime.

**Why rejected:**
This setup leaks port exposure, requires Nix rebuilds for simple endpoint updates, and creates a security gap during firewall reloads.

---

## Decision

**We choose Option A.**

Explicit scope: This decision applies to Gatus, Vector, Loki, Grafana, CrowdSec, and nftables firewall integration on `q958` and development hosts.

Implementation constraints:
- Gatus must run with a hardened systemd profile, using `CAP_NET_RAW` for pings.
- The `monitoring` SSH user is globally restricted to the check wrapper.
- All secrets are loaded from `/var/lib/secrets/` at runtime.

---

## Consequences

**Positive:**
- Updating monitored hosts/services is extremely fast.
- Attack surface is minimized by UDS check prioritization.
- Firewall security is robust and independent of bouncer startup timing.

**Negative:**
- Increased complexity due to loopback SSH key pair and command-forcing wrappers.

---

## Validation

- **Metric / signal:** Gatus dashboard shows all UDS and SSH loopback checks as green.
- **Review trigger:** Re-evaluate this ADR if Gatus SSH authentication fails frequently or if new services require complex custom check binaries.