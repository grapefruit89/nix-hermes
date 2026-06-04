---
title:        "ADR-22: Decoupled IoT & Zigbee2MQTT Architecture for SLZB-06"
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
  supersedes: [36_Home_Assistant_SLZB06_STRATEGY.md, 52_APPS_UPGRADE_STORAGE_ZIGBEE_MARCH_2026.md]
---

# ADR-22: Decoupled IoT & Zigbee2MQTT Architecture for SLZB-06

> **We establish a decoupled IoT Zigbee architecture utilizing Zigbee2MQTT and a local Mosquitto broker (Weg B) for our SLZB-06 (SMLIGHT) Ethernet Zigbee Coordinator. This replaces ZHA direct-socket coupling in Home Assistant (Weg A), adhering strictly to the Unix philosophy of isolation and state persistence.**

---

## Context

**What is the problem?**
In our home automation setup, coupling the SLZB-06 Ethernet coordinator directly to Home Assistant via ZHA (Weg A) creates a single point of failure. When Home Assistant restarts or undergoes updates:
1. The Zigbee mesh network drops entirely, disrupting all home automation controls.
2. Exotic or non-standard Zigbee hardware support is limited, leading to compatibility bottlenecks.
3. System logs and state transitions are coupled with the Home Assistant runtime, violating SRE isolation practices.

**Why does this matter?**
A robust, resilient homelab requires that critical physical automation layers (lighting, climate, sensors) remain functional and isolated from frontend updates and application-level failures.

---

## Considered Alternatives

### Option A: Zigbee2MQTT + Mosquitto (Aviation Grade) ← CHOSEN

**What it is:**
We run a dedicated Mosquitto MQTT broker on our server. We run a separate, systemd-sandboxed Zigbee2MQTT instance that connects to the SLZB-06 Ethernet coordinator over a LAN socket (`socket://<IP>:6638`). Home Assistant interacts with Zigbee exclusively through the Mosquitto MQTT broker.

**Pros:**
- **Decoupling:** Home Assistant restarts or updates do not disrupt the physical Zigbee mesh network.
- **Exotic Device Compatibility:** Zigbee2MQTT supports a significantly broader spectrum of devices than ZHA.
- **Isolation:** Follows the Unix philosophy. Zigbee translation and MQTT message brokerage are handled by independent, lightweight services.
- **SRE Portability:** The MQTT broker acts as a universal bus. Any consumer can subscribe to physical state updates without modifying coordinator configurations.

**Cons:**
- Requires maintaining two additional local services (Mosquitto and Zigbee2MQTT).

---

### Option B: ZHA (Direct Home Assistant Socket Binding) ← REJECTED

**What it is:**
Binding the SLZB-06 coordinator directly to Home Assistant via ZHA using raw TCP sockets.

**Why rejected:**
High operational fragility. If Home Assistant crashes, updates, or requires a restart, the entire Zigbee coordinator socket connection is severed, causing network instability and sensor dropouts across the homelab.

---

## Decision

**We choose Option A.**

We declare Zigbee2MQTT and Mosquitto as our standard IoT architecture with the following parameters:
1. **Network Interface:** LAN connection to the SLZB-06 coordinator via `socket://<IP>:6638`.
2. **Access Control:** Enforce strong authentication on the Mosquitto broker using SOPS-decrypted credentials.
3. **Isolation:** Sandboxed systemd execution for both Mosquitto and Zigbee2MQTT.

---

## Consequences

**Positive:**
- **Rock-Solid Stability:** The Zigbee mesh network is completely insulated from Home Assistant updates.
- **Extensive Hardware Support:** Instantly compatible with new Zigbee devices.
- **Network Telemetry:** Clean MQTT event logging makes debugging and auditing state transitions simple.

**Negative:**
- Minor configuration overhead in setting up both Zigbee2MQTT and Home Assistant MQTT auto-discovery.

---

## Validation

- **Signal:** Zigbee2MQTT successfully establishes a socket connection to the coordinator and publishes payload states to the Mosquitto broker.
- **Review frequency:** Every 12 months.
