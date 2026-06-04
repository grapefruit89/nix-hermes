---
title:        "ADR-10: Database Strategy, Caddy Gateway & Network Namespace Confinement"
domain:       10
folder:       10-network
status:       accepted
date:         2026-05-26
deciders:     [moritz]
review_after: 2027-05-26
links:
  guide:   10-network.md
  modules:
    - Nix Files/modules/10-network.nix
    - Nix Files/modules/60-apps.nix
  supersedes: [MASTER_ADR_Database_Strategy.md]
---

# ADR-10: Database Strategy & Metadata Tiering

> **We establish PostgreSQL as the primary standard for complex database-driven services and Valkey as the key-value cache engine, enforcing strict storage tiering that isolates all databases (including SQLite) from mergerfs pools to preserve POSIX locking compliance.**
> This ensures high availability, prevents data corruption, and optimizes database write IOPS on the Fujitsu Q958.

---

## Context

**What is the problem?**
In our homelab environment, system state is volatile by design (ephemeral root on `tmpfs`). However, persistent databases (for n8n, Miniflux, paperless, Vaultwarden) must survive reboot and stay protected from corruption. 

We face two main storage constraints:
1. **Mergerfs POSIX Limitations:** We utilize `mergerfs` to pool multiple HDDs. While excellent for media files, mergerfs does not fully support POSIX filesystem locks. Running database engines (PostgreSQL, SQLite) directly on a mergerfs mount leads to immediate locking errors, transaction deadlocks, and "Database Image Malformed" corruption.
2. **HDD Write Latencies:** Placing active databases on mechanical HDDs triggers significant latency spikes during intensive write operations (e.g. Radarr/Sonarr scanning or n8n workflows), degrading overall host responsiveness.

**Why does this matter?**
If database structures reside on incompatible mounts or slow HDDs, data corruption is inevitable, leading to silent service failures and catastrophic user data loss.

**Forces at play:**
- **Integrität:** Absolute protection against database locks and corrupt transactions.
- **Performance:** Sub-millisecond write latencies and high IOPS capacity.
- **KISS Compliance:** Use NixOS native service profiles (PostgreSQL, Redis-Valkey) rather than complex database wrapper configurations.

---

## Considered Alternatives

### Option A: Metadata Tiering to SSD/NVMe (Btrfs) + Unix Sockets ← CHOSEN

**What it is:**
We enforce a strict policy: all active database engines (PostgreSQL, Valkey, SQLite) MÜSSEN run directly on local fast storage (the SSD/NVMe tier `/persist` mounted with Btrfs compression `zstd` and `noatime`).
- **Postgres Live-Cluster:** Configured to run on `/data/state/postgresql-live` (which is bind-mounted directly to `/persist/data/state/postgresql-live`), completely bypassing `mergerfs`.
- **Valkey Engine:** Restricted to local Unix sockets and bound to `127.0.0.1`.
- **SQLite Databases (Vaultwarden):** Enforced to use `WAL` mode and stored on local SSD directories under `/var/lib`.

**Pros:**
- **Zero Corruption:** POSIX locks are fully supported by local Btrfs on NVMe/SSD.
- **Aggressive Performance:** SSD read/write speeds eliminate all disk bottlenecking.
- **High Security:** Unix socket auth prevents database network exposure.

**Cons:**
- Consumes space on the SSD tier (requires keeping system state clean and under 10GB).

---

### Option B: Databases on Mergerfs Mounts ← REJECTED

**Why rejected:**
Guaranteed database corruption due to the lack of POSIX lock support. Highly unstable.

---

## Decision

**We choose Option A.**

We enforce the following architectural rules:
1. **Data Directory:** PostgreSQL live data is forced to `/data/state/postgresql-live` (bound to SSD `/persist`).
2. **Mergerfs Isolation:** No database file (Postgres, Valkey, SQLite) may ever be stored on a path managed by `mergerfs`.
3. **Locale Compatibility:** The PostgreSQL server is locked to `en_US.UTF-8` messages and formats to guarantee consistent startup behavior regardless of default host locales.
4. **Valkey wrapper:** Valkey is declared using the native NixOS `services.redis` wrapper with `package = pkgs.valkey`.

---

## Consequences

**Positive:**
- **Extremely High IOPS:** Database operations execute in microseconds.
- **Crash Safety:** WAL mode and Btrfs metadata logging prevent data loss during power-cuts.
- **Clean Structure:** Databases are completely separated from volatile tmpfs and slow media HDDs.

**Negative:**
- Database storage is limited by the size of the SSD pool (mitigated by storing large backup dumps on Tier A storage).

---

## Validation

- **Signal:** PostgreSQL systemd logs show successful startup with locale `en_US.UTF-8`.
- **Review:** Re-evaluate if active state size exceeds 10GB.

================================================================================

# ADR-10-GATEWAY: Caddy Reverse Proxy & mTLS Fortress Ingress

> **We standardize on Caddy as our centralized, declarative gateway, building it with the custom `cloudflare` DNS-01 challenge plugin, and enforcing a strict dual-layer mTLS verification ("Admin Fortress") for sensitive admin interfaces.**
> This eliminates scattered Traefik label complexity and leaves Port 80 WAN closed globally.

---

## Context

**What is the problem?**
Legacy homelab setups relied on Traefik with dynamic Docker labels scattered across many docker-compose files. This lack of a single source of truth caused massive configuration drift. Furthermore, standard HTTP Let's Encrypt challenges require permanent open WAN access on Port 80, which is an unacceptable security exposure.

**Why does this matter?**
A homelab exposing administrative panels (like NixOS-Cockpit, SSH-Web, or Gatus) directly to subnets or Tailscale ranges faces risk of credential-stuffing or vulnerability exploits. We need a zero-knowledge gateway that performs pre-connection cryptographic checks on admin tools.

**Forces at play:**
- **Declarative Purity:** Proxy configurations must reside in single-file Nix attributes.
- **WAN Isolation:** Keep all ports closed except for secure entrypoints.
- **mTLS Strength:** Pre-authenticate administrators at the TLS handshake level before any backend bytes are served.

---

## Considered Alternatives

### 1. Standard Caddy vs Custom Caddy with Cloudflare DNS Plugin (xcaddy)

We choose a **custom Caddy build** compiling the `cloudflare` plugin natively inside NixOS packages (`caddy.withPlugins`):
* **Pros:** Allows Let's Encrypt DNS-01 challenges. Wildcard certificates (`*.m7c5.de`) are acquired silently in the background using zone DNS API tokens, keeping Port 80 WAN fully closed.
* **Cons:** Requires compiling plugins inside the Nix store (handled natively by Nixpkgs).

---

### 2. Standard TLS vs mTLS Fortress Client Verification (`require_and_verify`)

We choose **Mutual TLS (mTLS)** for all administrative services (the "Admin Fortress" pattern):
* **Pre-connection Block:** Caddy is configured with `client_auth { mode require_and_verify }` linking to a secure offline internal Root Certificate Authority (`internal-ca.pem`).
* **Cryptographic Guard:** Any client browser without a corresponding signed administrator certificate installed in their OS keychain is rejected at the TLS handshake layer, preventing them from even loading the login webpage.

```
[Administrator (with Cert)] ──(mTLS Handshake)──► [Caddy Gateway] ──► [Admin Service (Cockpit/Gatus)]
[Public Client (No Cert)]   ──(mTLS Handshake)──► [Caddy Gateway] ──► [BLOCKED: TLS Handshake Fails]
```

* **Pros:** Absolute protection. Attackers cannot brute-force or scan the backend because the gateway terminates the connection before HTTP traffic is initiated.
* **Cons:** Signed client certificates must be manually installed on the administrator's laptop and mobile devices.

---

## Decision

**We accept both strategies.**
1. **Custom Caddy Ingress:** Compile Caddy with the Cloudflare DNS plugin and run wildcard DNS-01 challenges.
2. **mTLS Admin Fortress:** Lock all admin subdomains (e.g. `nixos.m7c5.de`) behind client certificate verification.

---

## Consequences

**Positive:**
* Complete declarative control over wildcard certificate renewals.
* Admin services are invisible to nmap and unauthorized network scanners.
* Elimination of dynamic Docker label dependencies.

**Negative:**
* Expired or lost client certificates require manual root CA re-signing.

================================================================================

# ADR-10-VPN: Network Namespace Confinement & VPN Leak Prevention

> **We isolate download applications (such as SABnzbd) inside dedicated Linux Network Namespaces (`sabnzbd-ns`), forcing all external egress traffic and DNS lookups through a locked WireGuard tunnel interface (`wg-sabnzbd`), and monitoring connection integrity with a systemd-bound leak checker.**
> This guarantees complete protection against DNS and IP data leaks.

---

## Context

**What is the problem?**
Homelab systems run media stack downloaders that pull data from Usenet or torrent networks. If a VPN client runs system-wide, it affects all web traffic on the host, causing massive routing overhead and latency spikes. If the VPN client runs as a standard background service and the tunnel drops, the downloader immediately falls back to the host's cleartext ISP network connection (causing data exposure).

**Why does this matter?**
A simple crash of the VPN daemon must never result in cleartext IP exposures. Furthermore, standard virtual bridge configurations are highly susceptible to DNS leaks, exposing the server's activities to local ISP loggers.

**Forces at play:**
- **Leak Prevention:** Connections must instantly fail (kill-switch) if the VPN drops.
- **Service Independence:** Only the specific downloader must use the VPN; other services must use normal fast networks.
- **Resource Efficiency:** Avoid heavy virtual machine overhead by using lightweight Linux network namespaces.

---

## Considered Alternatives

### 1. Confinement via Dedicated Network Namespace (netns) ← CHOSEN

We isolate SABnzbd inside a dedicated network namespace (`sabnzbd-ns`) using systemd service bindings:
* **The Namespace:** A dedicated netns is created (`/run/netns/sabnzbd-ns`). Inside this namespace, the ONLY external network interface initialized is the WireGuard VPN client tunnel (`wg-sabnzbd`).
* **DNS Confinement:** All DNS resolutions are forced to use the VPN provider's DNS (`/etc/netns/sabnzbd-ns/resolv.conf`), making DNS leaks physically impossible.
* **The Bind:** The SABnzbd systemd service is bound directly to the namespace via `NetworkNamespacePath = "/run/netns/sabnzbd-ns"`.

* **Pros:** Absolute isolation. Since no other physical interfaces (like LAN or host WAN) are present inside `sabnzbd-ns`, if the WireGuard tunnel drops, all network traffic instantly terminates. No leaks can occur.
* **Cons:** Accessing the SABnzbd local admin GUI from the host LAN requires configuring a safe loopback socket or a local reverse proxy mapping.

---

### 2. Standard System-Wide VPN Routing ← REJECTED

**Why rejected:** High latency overhead for other host services, and very high risk of leakage if standard route configurations fail or reset during host package rebuilds.

---

## Decision

**We choose Option 1.**

We implement netns confinement with the following constraints:
1. **confinement:** SABnzbd runs strictly within the namespace path `/run/netns/sabnzbd-ns`.
2. **Leak-checking Daemon:** We run a systemd-timer-bound `leak-check` service that fetches the public IP from inside the namespace every 15 minutes. If it matches the host's public ISP IP, it triggers an emergency `systemctl stop sabnzbd`.
3. **Purity:** Namespaces are built and cleaned up declaratively using systemd `preStart` and `preStop` scripts.