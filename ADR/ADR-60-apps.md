---
title:        "ADR-60: Native Systemd-Sandboxed Applications, Central Dashboard, & PocketID SSO"
domain:       60
folder:       60-apps
status:       accepted
date:         2026-06-03
deciders:     [moritz]
review_after: 2027-06-03
links:
  guide:   60-apps.md
  modules:
    - Nix Files/modules/60-apps/default.nix
    - Nix Files/modules/60-apps/core.nix
    - Nix Files/modules/60-apps/automation.nix
    - Nix Files/modules/60-apps/iot.nix
supersedes: []
---

# ADR-60: Native Systemd-Sandboxed Applications, Central Dashboard, & PocketID SSO

> **We establish native, systemd-sandboxed services as the standard deployment model for all web applications (Vaultwarden, Paperless-ngx, Linkwarden, Filebrowser, Open WebUI), integrate them under a centralized declarative Homepage dashboard decoupled from Docker socket dependencies, and enforce single-sign-on (SSO) protection via PocketID forward authentication.**
> This guarantees maximum process isolation, resource efficiency on the Fujitsu Q958, and unified identity governance.

---

## Context

**What is the problem?**
In our homelab ecosystem, we run multiple helper apps (Vaultwarden, Paperless, Linkwarden, Open WebUI, Filebrowser). In legacy setups, these are run inside Docker containers with dynamic ports, volumes, and network layers. This introduces significant overhead, permission mapping issues, and security risks (e.g., exposing the Docker socket to the dashboard). Furthermore, we need a unified ingress path and SSO gateway to secure these apps without managing credentials in multiple databases.

**Why does this matter?**
Exposing multiple independent login screens increases the credential brute-force attack surface and leads to authentication configuration drift. In addition, Docker virtualization layers consume precious CPU and RAM cycles on our 16GB server.

**Forces at play:**
- **Isolation:** Web-facing applications must be strictly sandboxed from the host filesystem.
- **Identity:** Unified login state across administrative applications.
- **Resource Efficiency:** Native execution of binaries to reduce overhead.
- **SSoT Alignment:** All application parameters must be declared in Nix files.

---

## Considered Alternatives

### Option A: Native NixOS Services + PocketID SSO + Systemd Sandboxing ← CHOSEN

**What it is:**
We run all application backends directly as native NixOS services.
- **Systemd Sandboxing:** We apply strict sandboxing properties (`ProtectSystem = strict`, `ProtectHome = true`, `NoNewPrivileges = true`, `RestrictAddressFamilies`, `CapabilityBoundingSet = ""`) to each unit.
- **SSO Integration:** Caddy intercepts requests using `forward_auth` pointing to a local PocketID instance (`/api/auth/verify`). Admin interfaces (like Filebrowser, Linkwarden, Open WebUI) are only accessible after successful OIDC authentication.
- **Decoupled Dashboard:** The Homepage dashboard is populated statically via declarative Nix configuration without mounting the Docker socket or querying dynamic container states.

**Pros:**
- **Lowest Footprint:** Running native binaries eliminates Docker daemon overhead.
- **Premium Hardening:** Fine-grained kernel-level sandboxing restricts each service to its designated `/var/lib` directory.
- **Unified Auth:** Single-sign-on protects all endpoints under a single login.
- **High Security:** No root-privileged Docker sockets are exposed.

**Cons:**
- Upstream Nixpkgs services must exist for each application.

---

## Decision

**We choose Option A.**

We declare:
1. **Sandboxed Defaults:** Every web application service must run with strict systemd hardening options, restricting write access solely to its `/var/lib` folder.
2. **SSO Ingress:** Admin subdomains are wrapped in the `sso_auth` Caddy snippet.
3. **No Docker Containers:** No applications may run inside Docker containers on the production host.
4. **IoT Isolation:** Mosquitto and Zigbee2MQTT are restricted to local sockets and run under dedicated system users.

---

## Consequences

**Positive:**
- Flawless SSO authentication across the homelab.
- Massive memory savings compared to running Docker/Podman stacks.
- Centralized configuration management in `Nix Files/modules/60-apps/`.

**Negative:**
- Adding a new app requires writing a corresponding NixOS module declaration.

---

## Validation

- **Signal:** Applications start successfully, systemctl confirms active sandboxing profiles, and Caddy redirects unauthenticated subdomains to `auth.m7c5.de`.
- **Review frequency:** Every 12 months.