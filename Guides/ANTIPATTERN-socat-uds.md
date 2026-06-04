---
title: "Antipattern: Socket Proxying Workarounds (socat-uds)"
status: antipattern
tags: [antipattern, verboten, networking, security]
---

# 📛 ANTIPATTERN: Socket Proxying Workarounds (socat-uds)

> **We formally deprecate and discourage the use of auxiliary socket proxying/redirection daemons (such as running `socat` wrappers) to forcibly convert local TCP ports into UNIX Domain Sockets (UDS) for backends lacking UDS support (like Radarr, Sonarr, SABnzbd).**

### The Antipattern: What Was It?

In an effort to enforce a pure UNIX Domain Socket (UDS) ingress model for every single application (Caddy ↔ Backend UDS), administrators attempted to override the native TCP limitations of .NET-based (*arr) and Python-based (SABnzbd) applications. 

Since these backends lack native options to bind to UDS paths, a helper stack was created:
1. A systemd service ran `socat` in the background.
2. `socat` bound to `/run/radarr/radarr.sock`.
3. It redirected all incoming socket traffic to `127.0.0.1:7878` (where Radarr listened on TCP).
4. Caddy was then configured to talk to the UNIX socket `/run/radarr/radarr.sock`.

### Why It Is an Antipattern (The Drawbacks)

While it appears to achieve "purity", this UDS-to-TCP socket-proxy workaround introduces severe performance, complexity, and stability drawbacks:

#### 1. Increased Latency & CPU Overhead (Self-Defeating Goal)
Unix Domain Sockets are chosen to bypass the network stack overhead. However, when using `socat` to proxy UDS to TCP, every single HTTP payload undergoes dual serialization and virtual-network hops:
`Caddy ──► [UDS] ──► [socat] ──► [Loopback TCP] ──► [Radarr]`
This translation actually *increases* latency, context switching, and CPU usage compared to a direct Caddy ↔ Radarr loopback connection.

#### 2. High Fragility & Failure Rates
Adding `socat` introduces an auxiliary daemon per application. If `socat` crashes, encounters memory limits (OOM), or experiences permission blocks on `/run/radarr/`, the entire service goes offline—even if the Radarr backend is perfectly healthy.

#### 3. Permission & Namespace Complexity
UNIX sockets rely strictly on file-system ACLs. Forcing `socat` to run under the right users, whitelisting supplementary systemd groups (e.g. `caddy` group access to `radarr`), and managing temporary `/run/` state directories across system reboots introduces huge administrative overhead.

### The Modern, Secure Solution

We solve ingress communication securely by using **Hardened Local Loopback TCP Bindings** combined with strict systemd namespace sandboxing:

```
[External Traffic]
        │
        ▼
   [Caddy HTTPS]
        │ (Encrypted, hardened)
        ▼
   [Loopback TCP] ──► restricted to 127.0.0.1
        │
        ▼
 [Radarr Service] ──► systemd Sandbox: RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ]
```

#### Key Security Benefits of the Modern Solution:
* **Zero External Footprint:** Backends bind strictly to the loopback address (`127.0.0.1`)—never `0.0.0.0`—preventing any external LAN or WAN access.
* **Address Family Hardening:** The systemd unit for Radarr is locked down using `RestrictAddressFamilies = [ "AF_INET" "AF_UNIX" ]`. This prevents the process from initiating or accepting external network connections (no raw sockets, no public ethernet packets).
* **Native Zero-Hop Performance:** Traffic goes directly through the highly optimized Linux loopback driver (`lo`) in memory, yielding exceptional throughput and zero auxiliary daemon dependencies.
