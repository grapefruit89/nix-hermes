# DPlaneOS Architecture Analysis & Homelab Modernization Plan

This document extracts the design principles of the DPlaneOS storage operating system and analyzes our current NixOS-based homelab configuration. It concludes with a modernization roadmap.

---

## 🏗️ Aufgabe 1: Extraktion der Architektur-Prinzipien aus DPlaneOS

DPlaneOS is built on OpenZFS, NixOS, and PostgreSQL. We analyze its design across four core dimensions:

### 1. Deklarations-Philosophie (`PHILOSOPHY.md` & `NIXOS-README.md`)
- **Platform (OS) vs. Workload (Daemon)**:
  - **Platform Layer**: NixOS is the "appliance engine." It handles system booting, systemd services, network interfaces, firewall rules, and base system dependencies.
  - **Workload Layer**: A Go daemon (`dplaneosd`) manages dynamic storage constructs (ZFS pools, dataset hierarchies, encryption keys, NFS/SMB exports, and container states).
- **Separation (`configuration.nix` vs. `state.yaml`)**:
  - `configuration.nix` is static and declarative. It defines what packages are installed and how the system bootstraps.
  - `state.yaml` is dynamic. It allows storage modifications (adding datasets, changing quotas) at runtime.
  - **Consequence**: This separation keeps the operating system stateless and immutable. User storage operations do not require slow `nixos-rebuild` compilation cycles, minimizing runtime system interruption.

### 2. Reconciliation & GitOps-Architektur (`ARCHITECTURE.md` & `GITOPS-REFERENCE.md`)
- **Three-Layer Model**:
  - **Declaration**: The user specifies the target topology in `state.yaml` (desire).
  - **Reconciliation**: The reconciler compares the live state (via `libzfs` and system APIs) to the target. It calculates a diff and schedules execution.
  - **Execution**: The reconciler applies actions (creating datasets, binding mounts).
- **GitOps and `ignore_extraneous`**:
  - Git acts as the Source of Truth. If drift is detected, the reconciler aligns the system back to the Git state.
  - The parameter `ignore_extraneous` ensures that files, datasets, or users created outside of the declarative `state.yaml` are ignored rather than deleted. This allows safe, co-existing manual operations.

### 3. Sicherheits- & Betriebsmodell (`ARCHITECTURE.md` & `NIXOS-RATIONALE.md`)
- **Execution Whitelist (`internal/security/whitelist.go`)**:
  - The Go daemon executes commands using a strict, compiled-in list of permitted binaries and arguments.
  - By wrapping command execution and utilizing native `libzfs` C-bindings, DPlaneOS prevents shell injection vulnerabilities.
- **Impermanence (`NIXOS-RATIONALE.md`)**:
  - Root (`/`) is mounted on `tmpfs` (RAM).
  - State directories (such as the PostgreSQL database) are bind-mounted to `/persist`. This forces all state to be explicitly declared. Any configuration drift on `/` is wiped on reboot.

### 4. Operationale Integrität (`PHILOSOPHY.md`)
- **Drift Detection**: The reconciler computes the cryptographic and structural differences between declaration and reality, surfacing status metrics via CLI and UI.
- **`BLOCKED` State Safety**: Destructive operations (like pool deletion or dataset destruction) are categorized as `BLOCKED`. The engine refuses to execute them automatically to prevent accidental data loss.

---

## 📊 Aufgabe 2: Architekturanalyse meines bestehenden Setups

Comparing our 10-domain flat module setup on the Fujitsu Q958 to DPlaneOS yields the following gaps:

### Dimension-by-Dimension Gap Analysis

1. **Deklarations-Philosophie**:
   - *Current Status*: High coupling. Our Gatus checks, storage pools, and folder paths are declared directly inside NixOS modules like [30-storage.nix](file:///C:/Users/morit/Documents/Obsidian_Main/NixOS/Nix%20Files/modules/30-storage.nix) and [40-monitoring.nix](file:///C:/Users/morit/Documents/Obsidian_Main/NixOS/Nix%20Files/modules/40-monitoring.nix).
   - *Gap*: Any change to monitoring targets or storage pooling requires a full rebuild cycle.

2. **Reconciliation & GitOps**:
   - *Current Status*: Command-driven (reactive). We use udev rules in [35-automount.nix](file:///C:/Users/morit/Documents/Obsidian_Main/NixOS/Nix%20Files/modules/35-automount.nix) to trigger mounting scripts.
   - *Gap*: There is no central loop to reconcile state; the system reacts to physical triggers (unplug/plug) but cannot heal configuration drift.

3. **Sicherheits- & Betriebsmodell**:
   - *Current Status*: Impermanence is fully implemented on our server (ephemeral `/` on tmpfs with `/persist` binds).
   - *Gap*: There is no execution whitelisting. System shell scripts in our modules run commands with root privileges without systemd sandboxing restrictions on commands.

4. **Operationale Integrität**:
   - *Current Status*: Gatus monitors endpoints and mounts, alerting on failures.
   - *Gap*: Gatus is a passive observer. It does not prevent accidental deletion, nor does it block destructive operations.

### Reifegrad-Zusammenfassung (Maturity Summary)
> [!NOTE]
> Das System befindet sich auf dem Weg vom **halb-integrierten System** zu einer **Appliance**. Es verfügt über ein strukturiertes, deklariertes 10-Domänen-Modell und nutzt fortgeschrittene NixOS-Paradigmen wie Impermanenz und udev-gesteuertes Hot-Plugging. Die Schwachstelle ist das Fehlen eines eigenständigen Reconcilers und einer Entkopplung von Betriebssystem und Laufzeit-Datenkonfiguration. Es verhält sich wie ein gut orchestriertes Betriebssystem, noch nicht wie eine in sich geschlossene Speicher-Appliance.

---

## 🗓️ Aufgabe 3: Priorisierte, nicht-funktionale Roadmap

We prioritize optimizations focusing on architecture, safety, and operational stability:

| Priorität | Bereich | Konzept-Ziel | Konkrete Aktion |
| :--- | :--- | :--- | :--- |
| **Hoch** | *Security Hardening* | Limit systemd automounter privileges | Restrict `nixhome-automount@` service using systemd sandboxing (adding `CapabilityBoundingSet = [ "CAP_SYS_ADMIN" "CAP_CHOWN" "CAP_FOWNER" ];` and `PrivateNetwork = true;`). |
| **Hoch** | *Separation of Concerns* | Separate secrets from Nix store | Ensure Rclone configuration parameters containing API tokens are moved entirely to SOPS-decrypted configuration files. |
| **Mittel** | *State Management* | Ensure idempotency of automounter | Harden the `tiered-automount` bash script to handle edge cases where directory mountpoints already exist but are dangling or stale. |
| **Mittel** | *Drift Prevention* | Detect mount attribute drift | Add checks in Gatus that verify folder ownership (`root:media`) and permissions (`775`) on Tier B and Tier C mounts to alert on permission drift. |
| **Niedrig** | *Reproducibility* | Declarative disk layout initialization | Create a partition layout utility script in the workspace to format new drives automatically to the correct `TIER_*` partition table structures. |

---

## 🏁 Aufgabe 4: Schlussfolgerung & Nächste Schritte

Unser System steht auf einem **hervorragenden und extrem soliden Fundament**. Die flache Modulstruktur ist sauber und leicht zu warten. Ein größerer architektonischer Umbau ist nicht notwendig; stattdessen sollten wir gezielte Härtungsmaßnahmen durchführen.

Um den ersten Schritt in Richtung des DPlaneOS-Betriebsmodells zu gehen, können wir die systemd-Service-Sicherheit unseres Automounters in [35-automount.nix](file:///C:/Users/morit/Documents/Obsidian_Main/NixOS/Nix%20Files/modules/35-automount.nix) härten, indem wir das `CapabilityBoundingSet` beschränken und unnötige Linux-Systemzugriffe entziehen.

Füge die folgende Härtungskonfiguration zu `serviceConfig` in [35-automount.nix](file:///C:/Users/morit/Documents/Obsidian_Main/NixOS/Nix%20Files/modules/35-automount.nix) hinzu:

```nix
        CapabilityBoundingSet = [ "CAP_SYS_ADMIN" "CAP_CHOWN" "CAP_FOWNER" "CAP_DAC_OVERRIDE" ];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateNetwork = true;
```
