---
title: "Network & Database Guide: DNS Resolver, Valkey Cache & PostgreSQL Server"
domain: 10
folder: 10-network
status: active
complexity: 3
last_reviewed: 2026-05-26
links:
  adr:     ADR-10-network.md
  modules:
    - path: Nix Files/modules/10-network.nix
---

# Network & Database Guide: DNS Resolver, Valkey Cache & PostgreSQL Server

> **Operational guide for managing the homelab DNS server (AdGuard Home), Valkey key-value cache database, and the core PostgreSQL server on the fast NVMe/SSD tier.**
> Ensures local network resolution, caching efficiency, and database transaction stability.

---

## Prerequisites

Before performing database operations, ensure:
- [x] Host has at least 500MB of free space on `/persist` (fast storage tier).
- [x] PostgreSQL service directory `/data/state/postgresql-live` has correct owner `postgres:postgres`.
- [x] Local Unix socket path `/run/postgresql/` is accessible by system users.

---

## How It Works

- **AdGuard Home DNS:** Acts as the primary recursive nameserver for all LAN and Tailscale clients, using Cloudflare DoH as upstreams and maintaining an aggressive 32MB local RAM cache.
- **Valkey Caching:** Provides local in-memory caching on port `6379` for paperless, n8n, etc., automatically evicting oldest keys using `allkeys-lru` policies when hitting the 256MB limit.
- **PostgreSQL Server:** Acts as the transactional database engine. Data resides on fast SSD subvolumes `/data/state/postgresql-live` to guarantee high POSIX lock performance and eliminate Mechanical HDD read/write wear.

---

## Operational Procedures

### PostgreSQL Maintenance and Diagnostics

#### 1. Checking Database Service Status
```bash
systemctl status postgresql.service
```

#### 2. Logging in to the PostgreSQL Console (Local Unix Socket)
Since password authentication is disabled and socket-level Ident validation is active, you must run commands under the `postgres` user:
```bash
sudo -u postgres psql
```

#### 3. Listing Active Databases and Sizes
Inside `psql`:
```sql
\l+
```
Or via CLI:
```bash
sudo -u postgres psql -c "\l+"
```

#### 4. Creating Manual SQL Backups (Tier A target)
To prevent `mergerfs` locks, backup dumps should be written to `/data/state/postgresql/` (local SSD), which is subsequently synced to S3:
```bash
sudo -u postgres pg_dumpall > /data/state/postgresql/pg_backup_$(date +%F).sql
```

---

### Valkey Cache Diagnostics

#### 1. Checking Cache Health and Memory Usage
```bash
sudo -u redis valkey-cli info memory
```

#### 2. Monitoring Active Connections and Commands
```bash
sudo -u redis valkey-cli monitor
```

---

### AdGuard Home DNS Diagnostics

#### 1. Checking DNS Resolution Status
Verify local loopback resolution:
```bash
dig @127.0.0.1 -p 53 nixhome.local
```

#### 2. Scrape/View Query Statistics via API
```bash
curl -s http://127.0.0.1:20080/control/stats
```

---

## Verification Commands

These commands must pass to verify service health:

```bash
# 1. PostgreSQL is active and listening on the Unix socket
systemctl is-active --quiet postgresql && echo "PASS: PostgreSQL active"
ls -la /run/postgresql/.s.PGSQL.5432 && echo "PASS: Socket online"

# 2. Valkey is active and listening on port 6379
systemctl is-active --quiet redis-valkey && echo "PASS: Valkey active"
ss -tlnp | grep 6379 && echo "PASS: Valkey port open"

# 3. AdGuard Home is active and listening on port 53
systemctl is-active --quiet AdGuardHome && echo "PASS: AdGuard active"
ss -ulnp | grep :53 && echo "PASS: DNS port open"
```

---

## Known Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| PostgreSQL fails to start with "Locale not found" | System locale differs from `en_US.UTF-8` | Ensure `lc_messages` and settings are locked to `en_US.UTF-8` in Nix module |
| Postgres shows "locking protocol" errors | Data directory mapped to `mergerfs` path | Check `dataDir` in Nix module; ensure it points to `/data/state/postgresql-live` |
| Valkey fails with "Out of Memory" | Eviction policy not configured | Ensure `maxmemory-policy = "allkeys-lru"` is active inside settings |
| DNS resolution fails | Port 53 bound by another service (like systemd-resolved) | Disable systemd-resolved: `services.resolved.enable = false` in host config |

---

## NixOS-Native Wunschliste Gotchas: Caddy & Tailscale

### Caddy Reverse Proxy & Static Assets Ingress
* **The Gotcha (403 Permission Denied):** NixOS applies strict systemd hardening (`ProtectHome = true`) to Caddy by default. Caddy cannot read static HTML/assets located in `/home/moritz` or user folders, throwing `403 Forbidden` or `Resource temporarily unavailable` errors.
* **The Resolution:** 
  1. Store all static production web assets in `/var/www/` or `/var/lib/caddy/` and assign ownership to user `caddy`.
  2. If serving from user directories is unavoidable, override Caddy's systemd protection in `60-apps.nix`:
     ```nix
     systemd.services.caddy.serviceConfig.ProtectHome = lib.mkForce false;
     ```

### Tailscale Zero-Trust Ingress & Exit Nodes
* **The Gotcha (Total Loss of Internet when Exit Node Active):** If you configure this server as a Tailscale exit node or use an exit node client, returning packets may get silently dropped by NixOS's strict reverse path filtering.
* **The Resolution:** Enable loose reverse path checking inside your host configuration:
  ```nix
  networking.firewall.checkReversePath = "loose";
  ```
* **The Gotcha (Tailscale Bypassing Firewall):** Tailscale injects a custom `ts-input` chain into iptables/nftables by default, which permits all traffic on `tailscale0` and bypasses configured firewall rules.
* **The Resolution:** To enforce strict declarative NixOS firewall rules on the Tailscale interface, set the netfilter flag:
  ```nix
  services.tailscale.extraSetFlags = [ "--netfilter-mode=nodivert" ];
  ```
* **Seamless Tailscale Auto-TLS in Caddy:**
  To allow Caddy to automatically provision valid SSL certificates for your Tailscale domains (`host.tailnet.ts.net`), delegate cert permissions:
  ```nix
  services.tailscale.permitCertUid = "caddy";
  ```
  Caddy will automatically fetch the keys from `tailscaled` without needing Cloudflare DNS-01 API hooks!