---
title: "Security Domain Guide: Physical Hardware & Secrets Setup"
domain: 20
folder: 20-security
status: active
complexity: 3
last_reviewed: 2026-05-25
links:
  adr:     ADR-20-security.md
  modules:
    - path: Nix Files/modules/20-security.nix
---

# Security Domain Guide: Physical Hardware & Secrets Setup

> **Operational guide for managing SOPS secrets, LUKS2 encryption, and the Master USB Identity Anchor.**
> Ensures stateless system bootstrap and robust post-boot cryptographic hygiene.

---

## Prerequisites

Before configuring hardware identity triggers, ensure:
- [x] Host TPM2.0 is enabled in BIOS/UEFI.
- [x] System root uses impermanent (stateless) tmpfs.
- [x] SOPS master age key is printed/backed up in a secure physical location.

---

## How It Works (Sovereign Identity)

1. **Boot Phase:** The host starts from an impermanent (stateless) root (`tmpfs`).
2. **Key Access:** The system mounts the persistent state partition containing `/var/lib/sops-nix/key.txt`.
3. **Decryption:** The `sops-nix` engine reads the converted master age key `/var/lib/sops-nix/key.txt`.
4. **Secrets Injection:** In-memory secrets are decrypted on demand and injected directly into target systemd services without intermediate files, preventing secrets from leaking into the Nix store.

---

## Operational Procedures

### Converting SSH Host Key to Age Key (Initial Bootstrap)

To perform the initial bootstrap of `sops-nix` using the server's unique host key, run:

```bash
# 1. Create the sops-nix directory on persistent storage
sudo mkdir -p /var/lib/sops-nix

# 2. Convert host SSH private key to Age key
sudo bash -c 'nix-shell -p ssh-to-age --run \
  "ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key" \
  > /var/lib/sops-nix/key.txt'

# 3. Restrict file permissions
sudo chmod 600 /var/lib/sops-nix/key.txt
```

### Managing Encrypted Secrets

We have integrated custom shell aliases for convenient secret management. To view or edit secrets on the Fujitsu Q958:

```bash
# Edit secrets in interactive mode (using default system editor)
sops-edit

# Decrypt and show secrets in console
sops-show
```

---

## SSoT Key Schema

The interactive `secrets-setup.sh` script registers and encrypts exactly 12 keys. Ensure the following keys are set inside `secrets.sops.yaml` for system applications to run smoothly:

1. **`cloudflare_api_token`**: Infrastructure (Cloudflare DNS Challenge Zone API token)
2. **`privado_wg_key`**: Infrastructure (Privado VPN WireGuard private key)
3. **`pocket_id_secret`**: Infrastructure (Pocket ID OIDC secure secret)
4. **`sabnzbd_api_key`**: Media Stack (SABnzbd application API key)
5. **`vaultwarden_admin_token`**: Services (Vaultwarden administrative panel access token)
6. **`paperless_secret_key`**: Services (Paperless-ngx Django secret key)
7. **`miniflux_admin_password`**: Services (Miniflux administrative credentials)
8. **`linkding_secret_key`**: Services (Linkding database secret key)
9. **`n8n_encryption_key`**: Services (n8n workflow encryption password)
10. **`semaphore_cookie_hash`**: Services (Semaphore cookie hash string, 32+ characters)
11. **`valkey_password`**: Services (Valkey cache database access credentials)
12. **`openai_api_key`**: External APIs (OpenAI API key for integrated LLM operations)

---

## Verification Commands

Run these to verify system secrets health:

```bash
# 1. Verify sops age key file existence
ls -la /var/lib/sops-nix/key.txt

# 2. Check if systemd services successfully decrypted their sops secrets
systemctl status sops-nix.service

# 3. Test decrypting secrets via the shell alias
sops-show
```

---

## Known Failure Modes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| sops-edit fails with "age key not found" | Converted key `/var/lib/sops-nix/key.txt` is missing or unreadable | Re-run the SSH to Age conversion procedure and verify permissions |
| Service fails with systemd environment error | Key was saved in standard format rather than `KEY=VALUE` | Ensure secrets are stored exactly as `KEY="value"` inside the SOPS encrypted file |
| decryption error on rebuild | The public age key in `.sops.yaml` does not match the converted private key | Run `ssh-to-age` on the host SSH key with the `-pubkey` flag and update `.sops.yaml` |

---

## NixOS-Native Wunschliste Gotchas: sops-nix & fail2ban

### sops-nix Secrets Provisioning & Permissions
* **The Gotcha (Evaluation vs. Activation Phase):** You cannot directly read decrypted secret values inside your Nix expressions during Nix evaluation (e.g. using `builtins.readFile`) because `sops-nix` only decrypts them during the system activation phase.
* **The Resolution:** Configure your application to read its secrets from `/run/secrets/secret_name` at runtime (most modern services support a `..._FILE` environment variable) or use `sops.templates` to dynamically compile environment files containing the secrets.
* **The Gotcha (Permission Denied for Non-Root Users):** Decrypted secrets inside `/run/secrets/` default to ownership `root:root` with permissions `0400`. If non-root services attempt to read them, they will fail with permission errors.
* **The Resolution:** Explicitly declare the service user or group as the owner of the secret in `20-security.nix`:
  ```nix
  sops.secrets.vaultwarden_admin_token = {
    owner = "vaultwarden";
  };
  ```
* **The Gotcha (Decryption failure during User Creation):** If you use a `sops-nix` secret file to set a user's login password (e.g. `hashedPasswordFile`), the rebuild will fail because the user account must exist *before* secrets can be assigned, but the secrets decrypt *after* users are created.
* **The Resolution:** Tell `sops-nix` to decrypt the secret *before* user accounts are generated:
  ```nix
  sops.secrets.user_password = {
    neededForUsers = true;
  };
  ```

### Der Nix-Store-Vektor (Warum Klartext-Passwörter verboten sind)
* **The Gotcha (Globale Sichtbarkeit im Nix-Store):** Deklarierst du Standard-Passwörter, API-Keys oder Tokens direkt in deinen Nix-Modulen (z. B. `settings.password = "geheim"`), werden diese beim System-Build eins-zu-eins in den Nix-Store `/nix/store` einkompiliert.
* **Das Risiko:** Der Nix-Store ist standardmäßig für **jeden** Benutzer des Systems und jeden kompromittierten Dienst (z. B. eine infizierte Web-App) lesbar. Passwörter liegen somit unverschlüsselt auf dem Server im RAM-Dateisystem offen und sind für Angreifer im LAN/WLAN extrem leicht abzugreifen.
* **Die Resolution (Strikter SOPS-Standard):** Alle Passwörter und sicherheitsrelevanten Keys gehören ausnahmslos in `sops-nix`. Sie werden zur Laufzeit dynamisch und in-memory unter `/run/secrets/` entschlüsselt. Dies verhindert, dass ein kompromittierter Prozess auf fremde Zugangsdaten zugreifen kann.

---

### fail2ban Intrusion Prevention & Logging
* **The Gotcha (Failed SSH Attempts Not Tracked):** If `services.openssh.startWhenNeeded = true;` is active, NixOS spawns independent, ephemeral `sshd@<session>.service` units for each incoming SSH request. Fail2ban looks at `sshd.service` which remains empty, failing to record failed attempts.
* **The Resolution:** Disable socket activation for OpenSSH to consolidate all SSH logs in a single service:
  ```nix
  services.openssh.startWhenNeeded = false;
  ```
* **The Gotcha (Execution Failures of Advanced Actions):** Advanced Fail2ban actions (like `iptables-ipset` or `nftables` custom bans) will fail to run if they lack the required system tools in their systemd environment.
* **The Resolution:** Explicitly declare the firewall packages inside the Fail2ban package overlay:
  ```nix
  services.fail2ban.extraPackages = [ pkgs.ipset pkgs.iptables pkgs.nftables ];
  ```