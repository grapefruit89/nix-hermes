---
title: "Antipattern: Legacy iptables Firewall on Modern NixOS"
status: antipattern
tags: [antipattern, verboten, networking, firewall]
---

# 📛 ANTIPATTERN: Legacy iptables Firewall on Modern NixOS

In this guide, we document why using the legacy `iptables` firewall layer is considered an antipattern for modern NixOS deployments and explain why a pure `nftables` setup should be used instead.

### The Antipattern Defined

Configuring or enabling the legacy `networking.firewall` options in NixOS (which maps to the legacy `iptables` backend) is an antipattern. It results in a legacy ruleset wrapper, high CPU overhead under heavy packet rates, lack of atomic updates, and stateful tracking limitations that degrade overall server performance and predictability.

### Detailed Analysis & Architectural Mismatch

#### 1. Deprecated Linux Kernel Infrastructure
* **Legacy Design**: `iptables` uses a series of kernel tables (filter, nat, mangle, raw) that are evaluated sequentially for every packet. This sequential lookup design introduces high processing latency.
* **Kernel Status**: Modern Linux kernels have largely deprecated the underlying `xtables` kernel framework. Standard Linux systems (including NixOS) utilize translation wrappers (`iptables-nft`), which translate `iptables` rules into `nftables` bytecode at runtime. Running wrappers adds translation layers, debugging complexity, and potential bugs.

#### 2. Lack of Atomic Rule Updates
* **The Problem**: In `iptables`, changing a rule requires copying the entire ruleset from the kernel to the userspace, editing it, and writing the entire set back to the kernel. 
* **The Impact**: Under heavy networking traffic (such as during a DDoS/SYN-flood attack), updating or reloading the firewall ruleset in `iptables` can cause packet loss, connection drops, and high system lockups.

#### 3. Inefficient Set Operations (Rate Limiting & IP Blocking)
* **The Problem**: `iptables` has no native concept of intervals or high-performance sets. Blocking large country ranges (Geo-IP blocking) or doing rate-limiting with `iptables` requires creating thousands of individual linear rules, or relying on external tools like `ipset` which must be initialized separately.
* **The Impact**: Evaluating thousands of linear rules degrades packet processing speed linearly. In contrast, `nftables` supports native hash sets and interval sets, allowing IP subnets to be looked up in `O(1)` time regardless of set size.

#### 4. Bypassing and Conflicting Rulesets
* In NixOS, many services (like Tailscale) inject their own rules directly into the firewall. When using legacy `iptables`, these rules can conflict, override local rules silently, or bypass security chains entirely. `nftables` uses a clean, single-table architecture where priority-based chains determine evaluation order explicitly.

### Correct Pattern: Pure nftables

Instead of legacy `iptables`, all modern servers must implement a pure `nftables` configuration:
* **Disable Legacy Firewall**: Explicitly set `networking.firewall.enable = false;` in the hosts configurations.
* **Native nftables**: Set `networking.nftables.enable = true;` and provide a declarative ruleset inside `networking.nftables.ruleset`.
* **Stateful Throttling**: Use native nftables sets with timeouts (dynamic sets) for SSH brute force protection and SYN-flood mitigation.
* **Atomic IP Blocking**: Use interval sets (`type ipv4_addr; flags interval;`) for fast Geo-IP blocks.

### Verification & Diagnostic Commands

When `nftables` is active, use these native diagnostic utilities:
* **Show entire active ruleset:**
  `sudo nft list ruleset`
* **Show blocked Geo-IP set elements:**
  `sudo nft list set inet filter geoip_blocked`
* **Check the state of SSH rate-limit meters:**
  `sudo nft list set inet filter ssh_meter`
* **Inspect live packet logs:**
  `sudo journalctl -k -f --grep="nftables-dropped"`
