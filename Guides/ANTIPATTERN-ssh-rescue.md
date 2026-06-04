---
title: "Antipattern: Time-Based SSH Recovery Windows"
status: antipattern
tags: [antipattern, verboten, security, ssh]
---

# 📛 ANTIPATTERN: Time-Based SSH Recovery Windows

> **We formally deprecate and prohibit time-based, boot-time SSH password authentication services (historically referred to as `ssh-rescue` or `ssh-recovery-window`). These services are replaced by secure Dropbear-based initrd-SSH on port 2222.**

### The Antipattern: What Was It?

In legacy homelab configurations, administrators frequently worried about losing access to their private keys and locked hosts. To circumvent permanent lockout, a systemd script named `ssh-rescue.nix` was introduced:
1. Upon system boot, a one-shot service temporarily modified `/etc/ssh/sshd_config` using `sed`.
2. It enabled `PasswordAuthentication yes` and reloaded the SSH daemon.
3. The script slept for **5 minutes** (300 seconds).
4. After 5 minutes, it ran another `sed` command to set `PasswordAuthentication no` and reloaded the daemon.

### Why It Is Highly Dangerous (The Vulnerabilities)

This temporary time-window recovery script introduces severe security and operational vulnerabilities:

#### 1. The Boot-Time Race Condition
If an attacker triggers a physical power cycling or forces a reboot of the server, a **5-minute open-ingress window** is established. During this window, anyone on the network can attempt brute-force password attacks against the user and root accounts.

#### 2. Lockout Due to Script Failures or Crashes
If the host server encounters memory pressure (OOM) or the sleep/recovery service crashes or hangs *during* the 5-minute window, the SSH daemon remains permanently configured with `PasswordAuthentication yes`. This leaves the system completely exposed in production.

#### 3. Mutability and Configuration Drift
Imperative string manipulation (e.g. `sed` on `/etc/ssh/sshd_config`) breaks the core tenet of NixOS purity. It leads to structural configuration drifts and makes it extremely difficult to verify the cryptographic state of the daemon at any given second.

#### 4. TTY-Interferenz durch Countdown-Skripte (Das Konsolen-Desaster)
Wird ein temporäres Rettungsfenster mit einem aktiven Countdown im Terminal (z. B. eine Schleife mit `echo` und `sleep`) auf der Konsole ausgegeben, führt dies zu einer schweren TTY-Korruption:
* **Eingabe-Überschreibung:** Die ständigen Ausgaben auf `stdout` oder `/dev/console` überschreiben das Terminal-Echo und die Cursor-Position.
* **Eingabe-Blockade:** Jegliche interaktive Passworteingabe oder Tastaturinteraktion des Administrators wird visuell und eingabeseitig zerschossen, wodurch eine Rettung unmöglich wird.
* **Verbot:** Schleifen, die während interaktiver Eingabeaufforderungen (wie Passworteingaben) Text an die TTY streamen, sind strikt als destruktives Systemverhalten verboten.

#### 5. TTY-Interferenz durch Kernel-Log-Spamming (Console Flooding)
* **Das Problem:** Bei Fehlern oder Hardware-Wechseln fluten Kernel-Meldungen (`dmesg` wie z. B. Link-State-Updates oder USB-Fehlermeldungen) die aktive Konsole. Diese Meldungen grätschen mitten in die interaktive Passworteingabe der LUKS-Entschlüsselung hinein, wodurch das Prompt unlesbar wird.
* **Verbot:** Ungefilterte Kernel-Ausgaben während der Passworteingabephase.
* **Die Lösung:** Kernel-Parameter müssen über `boot.kernelParams` zwingend auf ein ruhiges Niveau gedrosselt werden (`loglevel=3` und `quiet`), damit die Eingabe sauber bleibt.

#### 6. TTY-Interferenz durch Multiplexing-Konflikte (Passwort-Race-Conditions)
* **Das Problem:** Wenn das System gleichzeitig auf der physischen Konsole (TTY1) und in der Dropbear-SSH-Sitzung einen Passwort-Agenten startet, konkurrieren beide Prozesse um den Eingabe-Fokus (`stdin`). Tastaturanschläge werden fragmentiert und teilweise an den falschen Empfänger geleitet.
* **Verbot:** Unkoordinierte parallele Passwortabfragen auf mehreren Kanälen.
* **Die Lösung:** Systemd-Steuerung, die Eingaben sauber synchronisiert und den TTY-Fokus gezielt an das aktive Interface leitet.

#### 7. STDIN-Blockade in Headless-Skripten (Silent Boot-Hangs)
* **Das Problem:** Ein Boot-Skript ruft einen Befehl auf, der unerwartet auf eine Tastaturinteraktion wartet (z. B. `fsck` bei Festplattenfehlern mit der Frage `y/n` oder interaktive Paketbestätigungen), während kein Terminal angeschlossen ist (Headless-Modus). Der Bootvorgang friert bei 99% geräuschlos ein.
* **Verbot:** Ausführen blockierungsgefährdeter Befehle ohne explizite Non-Interactive-Flags.
* **Die Lösung:** Zwingender Einsatz von Flags wie `-y`, `-f` oder das Umleiten der Eingabe (`< /dev/null`) bei allen autonomen Systemskripten.

### The Modern, Secure Solution

We solve host recovery securely using the **initrd-SSH Dropbear / TinySSH Ingress** cascade:

```
[System Boot]
     │
     ▼
[Initrd Stage]
     │
     ├─► Enters Sovereign LUKS Decryption Phase
     │
     └─► Launches Dropbear SSH (Port 2222)
           │
           ├─► Whitelists EXACT administrative SSH Keys
           │
           ├─► Enters systemd-tty-ask-password-agent
           │
           └─► Performs Zero-Knowledge Boot Decryption
```

#### Key Security Benefits of the Modern Solution:
* **No Password Authentication:** Decryption and terminal access at the boot stage require the administrator's physical SSH key—never plaintext passwords.
* **No Runtime Exposure:** Once the system enters the multi-user runtime target, the Dropbear initrd service is fully terminated and unmounted. It is physically impossible to access it post-boot.
* **Declarative Purity:** Configured entirely via declarative Nix options (`boot.initrd.network.ssh`) in the active security module. No raw bash shell manipulation of runtime system files.
