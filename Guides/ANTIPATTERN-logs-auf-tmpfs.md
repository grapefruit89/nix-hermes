---
title: "Antipattern: Keeping Logs Exclusively on Ephemeral tmpfs"
status: antipattern
tags: [antipattern, verboten, logging, security]
---

# 📛 ANTIPATTERN: Keeping Logs Exclusively on Ephemeral tmpfs

In this guide, we document why keeping system and service logs purely on ephemeral memory (`tmpfs` on `/var/log`) represents an antipattern for a secure and observable homelab server environment.

### The Antipattern Defined

Running an impermanent NixOS setup where the root filesystem `/` is wiped on reboot without persistent log shipping or persistent journal storage is an antipattern. It results in a total loss of forensic evidence, inability to debug boot issues after crashes, and zero historical visibility into system events.

### Detailed Analysis & Architectural Risk

#### 1. Loss of Forensic Evidence After Security Incidents
* **The Scenario**: If an unauthorized entry attempt occurs (e.g. brute-forcing SSH or scanning PocketID login endpoints), the logs detailing the client IP, timestamps, and usernames are stored inside `systemd-journald` in `/var/log/journal`.
* **The Vulnerability**: If the attacker triggers a kernel panic or causes the system to reboot, the `/var/log` tmpfs partition is cleared. When the server boots back up, all evidence of the intrusion is gone. This makes post-mortem forensics impossible.

#### 2. Post-Crash Debugging Failure
* **The Scenario**: The system experiences a hardware lockup, Btrfs filesystem errors, or out-of-memory (OOM) daemon kills.
* **The Problem**: To find out why the crash occurred, you need to read the kernel logs (`dmesg`) and system logs right before the crash. If logs are stored on tmpfs, they are wiped by the reboot. You have no way of knowing what triggered the crash.

#### 3. Fail2ban Database Drift and Lockouts
* **The Scenario**: Fail2ban scans `/var/log` or the systemd journal socket to locate bad actors and ban them.
* **The Problem**: When the system reboots, Fail2ban loses its historical state and memory of active bans. It must start scanning logs from scratch, giving malicious actors another window to attack before the ban triggers again.

### Correct Pattern: Centralized Logging with Loki & Vector

To solve this, we implement **Centralized, Hardened Logging**:
1. **Log Shipper (Vector)**: Runs locally, reads the live stream from the journald socket, and immediately forwards it to Loki.
2. **Log Storage (Loki)**: Runs as a native daemon, saves chunks in a persistent path `/var/lib/loki` which is linked to `/persist` in the storage config.
3. **Dashboard (Grafana)**: Re-reads logs from Loki, providing a secure, queryable history that survives reboots.

#### 💾 Option: Persistent vs Volatile journald
In this configuration, we choose to keep the primary `journald` logs on `tmpfs` to avoid write wear on the persistent SSD partition, but we **must** ensure that:
* **Loki's storage is persistent**: `/var/lib/loki` is placed in `tierA.paths`.
* **Grafana's database is persistent**: `/var/lib/grafana` is placed in `tierA.paths`.
This combination gives us the best of both worlds: zero systemd-write wear on `/var/log/journal`, but a fully persistent, searchable log database in Loki/Grafana that survives reboots.
