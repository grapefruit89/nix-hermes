---
title: "Impermanence Guide: Blank Snapshot Persistence & Stateless Rollbacks"
domain: 0
folder: 00-core
status: active
complexity: 3
last_reviewed: 2026-05-26
links:
  adr:     ADR-00-core.md
  modules:
    - path: Nix Files/modules/00-core.nix
    - path: Nix Files/modules/20-security.nix
---

# Impermanence Guide: Blank Snapshot Persistence & Stateless Rollbacks

> **Operational guide for maintaining an ephemeral homeserver with blank snapshot rollbacks on boot (Misterio77 standard).**
> Guarantees a pristine filesystem state and structural reproducibility.

---

## How It Works (Ephemerality in Action)

```
[System Power On]
        │
        ▼
[Initrd Mount Stage]
        │
        ├─► 1. Mount Btrfs parent volume to temporary path (/mnt)
        ├─► 2. Delete existing dirty "@root" subvolume
        ├─► 3. Create fresh "@root" subvolume from blank "@blank" snapshot
        └─► 4. Unmount temporary path and proceed with boot
```

Because the active `/` root partition is completely wiped and reconstructed from a blank subvolume during early boot, any configuration drift or unversioned files created during operation are instantly vaporized. Only directories explicitly bound to persistent volumes survive.

---

## Operational Procedures

### 1. Declaring Persistent Bindings (sops-nix / system state)

To ensure system stability, key identity and state directories must be whitelisted for persistence. In our active [20-security.nix](file:///C:/Users/morit/Documents/Obsidian_Main/NixOS/Nix%20Files/modules/20-security.nix) and core modules, the following directories are bound:

```nix
# Example of declarative impermanence bindings
environment.persistence."/persist" = {
  hideMounts = true;
  directories = [
    "/var/log"
    "/var/lib/nixos"
    "/var/lib/systemd/coredump"
    "/etc/NetworkManager/system-connections"
  ];
  files = [
    "/etc/machine-id"
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
  ];
};
```

---

### 2. Boot-Time Rollback Script (Btrfs Standard)

If using a Btrfs root subvolume, the rollback script is integrated into `boot.initrd.postDeviceCommands`:

```bash
# Wiping the root subvolume on Btrfs early-boot stage
mkdir -p /mnt
mount -o subvol=/ /dev/disk/by-label/DISK_SYSTEM /mnt

if [ -e /mnt/@root ]; then
    echo "Wiping @root subvolume..."
    btrfs subvolume delete /mnt/@root
fi

echo "Restoring pristine @root subvolume..."
btrfs subvolume snapshot /mnt/@blank /mnt/@root

umount /mnt
```

---

## Verification & Troubleshooting

If you suspect persistence issues or state loss:

### 1. Check Passive File Survival
Create a test file on root, reboot, and verify that it vanished:
```bash
# Run this test
echo "temporary" > /test-ephemeral.txt
reboot

# After boot:
cat /test-ephemeral.txt
# Expected output: cat: /test-ephemeral.txt: No such file or directory
```

### 2. Check Active Bindings
Verify what directories are persistently mounted under `/persist`:
```bash
mount | grep /persist
```

---

## Known Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| SSH connection fails after reboot | Host SSH key was not whitelisted in persistence | Recover from backup and add `/etc/ssh/ssh_host_ed25519_key` to files list |
| Database fails with Lock Error | DB state directory lies on non-POSIX persistent MergerFS pool | Move database dataDir explicitly to SSD Btrfs `/data/state/` |
| System logs eating up RAM | `/var/log` on tmpfs is bloated by debug logging | Restrict systemd log limits inside `/etc/systemd/journald.conf` |
