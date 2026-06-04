---
title: "Boot Guide: Sovereign initrd TPM2 Unlock & Dropbear SSH"
domain: 20
folder: 20-security
status: active
complexity: 5
last_reviewed: 2026-05-26
links:
  adr:     ADR-20-security.md
  modules:
    - path: Nix Files/modules/20-security.nix
---

# Boot Guide: Sovereign initrd TPM2 Unlock & Dropbear SSH

> **Operational guide for managing the secure multi-factor boot-chain, including initrd systemd, local LUKS decryption via TPM2/FIDO2 keys, remote network-bound decryption using Dropbear SSH on Port 2222, and SOPS Age key recovery.**
> Guarantees an autonomous, unattended startup while securing local storage pools against physical theft.

---

## Prerequisites

Before configuring hardware-based decryption or initrd network unlock, verify:
- [x] Host motherboard has TPM 2.0 active in UEFI settings.
- [x] Ephemeral root (`tmpfs` on `/`) is active, with the persistent storage array mapped under `/persist` (Tier A).
- [x] Host network adapter is configured and initialized at UEFI/initrd level.

---

## The Sovereign Boot-Chain Pipeline

```
 [Power On]
     │
     ▼ (initrd loading)
[Stage-0: USB Fingerprint] ──(Checks NIXHOME_BOOT signature)──► [Access Granted]
     │
     ▼ (Decryption handshake)
[Stage-1: LUKS Multi-Factor] ──┬─► [Local: TPM2 Chip / FIDO2 key]
     │                         └─► [Remote: Network Dropbear SSH (Port 2222)]
     ▼ (OS initialization)
[Stage-2: Ephemeral Mounts] ──(Rolls back tmpfs / Btrfs snapshot)──► [Stateless Boot]
```

1. **Stage-0 (Hardware Fingerprint):** The initrd bootstrap checks for the presence of a hardware USB key labeled `NIXHOME_BOOT` containing transient credentials.
2. **Stage-1 (Decryption Handshake):** The LUKS master keys for `sovereign_vault` are decrypted locally using TPM2 or a FIDO2 token. If local validation fails (e.g. headless boot, remote maintenance), a Dropbear SSH service is active on Port 2222 to allow manual password input.
3. **Stage-2 (Stateless Mounts):** The decrypted volumes are mounted. The operating system rolls back the `/` partition to a blank state, mapping permanent variables strictly to `/persist` on Tier A SSD.

---

## Operational Procedures

### Remote Network Decryption via SSH

If the host fails to boot autonomously (e.g. TPM state invalidation due to a firmware upgrade), you can unlock the LUKS container remotely:

```bash
# 1. Connect to the initrd Dropbear SSH service (Port 2222)
# The host signature uses the persisted key to prevent SSH warnings
ssh root@your-server-ip -p 2222

# 2. Enter the LUKS passphrase to unlock the volume
# (Systemd in initrd will automatically capture the passphrase and resume the boot sequence)
systemd-tty-ask-password-agent
```

### Binding LUKS Decryption to TPM2

To enroll the local motherboard's TPM 2.0 chip for zero-touch boots, execute the following command (requires systemd in initrd active):

```bash
# Enroll TPM2 to release the LUKS key automatically during UEFI PCR state validation
systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7 /dev/disk/by-label/NIXHOME_CRYPT
```

### SOPS Age Key Recovery & Backup

The master Age key `/var/lib/sops-nix/key.txt` is the single source of truth for decrypting all SOPS secrets. If this key is lost, your system cannot boot.

```bash
# 1. Back up your host SSH key and convert it to Age format
nix-shell -p ssh-to-age --run "ssh-to-age -private-key -i /persist/etc/ssh/ssh_host_ed25519_key > /persist/var/lib/sops-nix/key.txt"

# 2. Back up the age key securely to an encrypted offsite volume
# Keep the backup detached from the host filesystem
```

---

## Declarative Configuration Standard (NixOS)

The initrd security parameters are managed natively inside the `20-security.nix` module:

```nix
boot.initrd = {
  systemd.enable = true; # Mandatory for cryptenroll & TPM2/FIDO2
  
  luks.devices."sovereign_vault" = {
    device = "/dev/disk/by-label/NIXHOME_CRYPT";
    preLVM = true;
    crypttabExtraOpts = [ "tpm2-device=auto" "fido2-device=auto" ];
  };

  network = {
    enable = true;
    ssh = {
      enable = true;
      port = 2222;
      authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5..." ];
      hostKeys = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
    };
  };
};
```

---

## Verification & Diagnostics

### Verify Cryptenroll Devices

```bash
# Check enrolled keys on the crypt device
systemd-cryptenroll /dev/disk/by-label/NIXHOME_CRYPT
```

### Test SSH Remote Connection

```bash
# Run a dry-run port scan to verify initrd network accessibility
nc -zv your-server-ip 2222
```

---

## Known Failure Modes

| Symptom | Likely Cause | Operational Fix |
|:---|:---|:---|
| Remote decryption SSH prompts with "Host Key Verification Failed" | The host key file was recreated or not persistently mapped | Map `hostKeys` to a fixed path `/persist/etc/ssh/ssh_host_ed25519_key`. Keep host fingerprints in your client's `.ssh/known_hosts` stable. |
| TPM2 unlock fails after a BIOS update | BIOS flash invalidated PCR states (PCR 0/2/7 changed) | Boot via Dropbear SSH, unlock manually, then run systemd-cryptenroll again to bind to the new PCR values. |
| Systemd boot-chain hangs at Stage-0 | USB key `NIXHOME_BOOT` missing or corrupted | Plug in the backup USB key or override Stage-0 validation manually via UEFI shell flags. |
