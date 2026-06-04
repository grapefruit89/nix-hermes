---
title: "Antipattern: Global Firewall Disabling (Bastelmodus)"
status: antipattern
tags: [antipattern, verboten, security, firewall]
---

# 📛 ANTIPATTERN: Global Firewall Disabling (Bastelmodus)

> **We formally deprecate and prohibit the use of a global `bastelmodus` (development/diagnostic mode) flag that disables the NixOS firewall system-wide (`networking.firewall.enable = !bastelmodus`). This configuration vulnerability is tracked under `CVE-NIXH-001`.**

### The Antipattern: What Was It?

In legacy development stages, troubleshooting networking, container bridges, or service binding issues led to lockouts. To simplify testing, a global boolean option `bastelmodus` was declared:
```nix
# The Vulnerable Anti-Pattern
networking.firewall.enable = !bastelmodus;
```
If a service failed to communicate, the administrator toggled `bastelmodus = true`, which completely turned off the system-wide NixOS firewall.

### Why It Is Highly Dangerous (The Vulnerability `CVE-NIXH-001`)

Disabling the entire firewall introduces severe, system-wide security blackouts:

#### 1. Global Broadcast Domain Exposure
Fujitsu Q958 homeservers are frequently relocated or used in dual environments. Toggling `bastelmodus = true` while connected to a shared network (such as a coworking space, conference, or untrusted LAN) leaves every open port, system socket, and development API completely exposed to local network scans (`nmap -sV`).

#### 2. Escalation of Blast Radius
Because `bastelmodus` was tied to other deployment automations (like passwordless sudo in `automation.nix`), disabling the firewall simultaneously stripped down system authorization limits, creating an ideal vector for local privilege escalation.

#### 3. Masking underlying binding issues
Disabling the firewall hides structural interface binding issues (e.g. binding a service to `0.0.0.0` instead of `127.0.0.1`). When the firewall is eventually re-enabled, the system immediately locks out.

### The Modern, Secure Solution

We solve network diagnostic troubleshooting using a **Structured, Interface-Specific Diagnostic Mode**:

```
[Incoming Connection]
         │
         ▼
[NixOS nftables Firewall]
         │
         ├─► Interface = Tailscale (tailscale0)? ──► [TRUSTED: Allowed]
         │
         ├─► Source IP = LAN Range (RFC1918)? ──► [TRUSTED: Allowed]
         │
         └─► Interface = WAN / Public? ──► [BLOCKED: Drops Packet]
```

#### Key Security Benefits of the Modern Solution:
* **Interface Isolation:** The firewall remains active at all times. If troubleshooting is needed, we open ports only on the trusted `tailscale0` virtual interface using `networking.firewall.interfaces.tailscale0.allowedTCPPorts`.
* **Subnet Whitelisting:** Traffic is allowed only from private subnets (RFC1918) and trusted Tailnet CGNAT ranges (`100.64.0.0/10`), keeping the WAN perimeter completely locked.
* **Strict Binding:** Production services bind explicitly to loopback `127.0.0.1` or unix domain sockets (UDS) and proxy through Caddy, rather than exposing ports on open interfaces.
