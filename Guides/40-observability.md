---
title: "Domain 40: operational guide for Gatus health checks, VLG logging & CrowdSec hardening"
domain: 40
folder: 40-monitoring
status: active
complexity: 3
last_reviewed: 2026-06-03
links:
  adr:     ADR-40-monitoring.md
  modules:
    - path: Nix Files/modules/40-observability.nix
---

# Domain 40: Operational Guide for Observability & Hardening

Dieses Dokument ist die zentrale Betriebsanleitung für unsere Observability-Infrastruktur. Sie beschreibt das Gatus-Monitoring, das Vector + Loki + Grafana (VLG) Log-System sowie das CrowdSec-Härtungskonzept an.

---

## 🌐 Teil 1: Gatus Homelab Monitoring Scheme

Gatus läuft auf dem Host und lauscht ausschließlich auf `127.0.0.1:8084` (SSO-gesichert über Caddy unter `gatus.m7c5.de`).

### Endpunkt-Klassifizierungen in Gatus

#### 1. Network & Connectivity (Gruppe: `network`)
- **Internet Ping**: `icmp://1.1.1.1` prüft die WAN-Erreichbarkeit alle 30 Sekunden.
- **Blocky DNS Resolver**: `dns://127.0.0.1:53` prüft, ob `cloudflare.com` mit `NOERROR` aufgelöst wird.

#### 2. Storage & Pools (Gruppe: `storage`)
- **MergerFS Fast Pool**: SSH-Check führt `/run/current-system/sw/bin/check-fast-pool` aus (prüft `/mnt/fast_pool` und aktive Tier B Branches).
- **MergerFS Media Pool**: SSH-Check führt `/run/current-system/sw/bin/check-media-pool` aus (prüft `/mnt/media` und aktive Tier C Branches).
- **MergerFS External Pool**: SSH-Check führt `/run/current-system/sw/bin/check-external-pool` aus (prüft externe Backup-Platten).
- **Permissions Drift**: SSH-Check führt `/run/current-system/sw/bin/check-permissions-drift` aus (stellt `root:media` und `775/2775` auf Tier B/C Mountpoints sicher).

#### 3. Database & Core (Gruppe: `core`)
- **PostgreSQL Socket**: UDS-Check führt `check-postgres-uds` aus.
- **Valkey Socket**: UDS-Check führt `check-valkey-uds` aus.
- **SSH Daemon**: `tcp://127.0.0.1:53844` prüft den SSH-Hauptport.

#### 4. Media & App-Dienste
- Gatus prüft alle laufenden Webservices (Jellyfin, Sonarr, Radarr, SABnzbd, Pocket-ID, Vaultwarden, Paperless-ngx, n8n, Forgejo, Semaphore, AMP) auf ihren HTTP 200/Health-Endpoints.

---

## 🔒 Teil 2: Unix Socket Priorisierung & Gatus Härtung

Da Gatus nativ keine Unix-Domain-Sockets (UDS) abfragen kann, greifen wir auf ein sicheres SSH-Loopback-Verfahren zurück:

### UDS-zu-SSH Mapping
Gatus verbindet sich per SSH als Benutzer `monitoring` auf `127.0.0.1`.
- **Eingeschränkter SSH-Key**: In `authorizedKeys` wird der Zugriff auf den Befehl `/run/current-system/sw/bin/gatus-ssh-wrapper` beschränkt:
  `restrict,command="/run/current-system/sw/bin/gatus-ssh-wrapper" <SSH_PUB_KEY>`
- Der Wrapper erlaubt ausschließlich die Ausführung von registrierten Prüfskripten (`check-*` in `/run/current-system/sw/bin/`).

### Timeout-Verhalten für Festplatten-Spin-up
- MergerFS-Pool-Prüfungen können bis zu 15 Sekunden dauern, falls die HDDs aus dem Standby aufgeweckt werden müssen (HDD spin-up delay).
- In der Gatus-Endpunktkonfiguration ist das Timeout für storage-bezogene Checks explizit auf `timeout: "20s"` angehoben, um Fehlalarme zu vermeiden.

---

## 📊 Teil 3: Vector + Loki + Grafana (VLG) Log-Architektur

Unser Logging-Stack läuft vollständig ohne Docker-Container direkt auf NixOS.

### Datenfluss
1. **Vector**: Liest den systemd-journald-Socket ein, filtert Caddy-JSON-Logs sowie Systemd-Dienste, parst sie über VRL (Vector Remap Language) und reichert sie mit Metadaten an.
2. **Loki**: Nimmt die Log-Streams von Vector auf und speichert sie verschlüsselt auf dem persistenten Pfad `/var/lib/loki` (mit einer 7-Tage-Retention-Period).
3. **Grafana**: Visualisiert Logs und Metriken über die vorkonfigurierte Loki-Datenquelle (SSO-gesichert unter `grafana.m7c5.de`).

### Persistenz-Konzept (Anti-Log-Spam)
Um Schreibzugriffe auf die SSD-Partition zu minimieren, bleiben die raw `journald`-Logs flüchtig im RAM (`tmpfs` auf `/var/log`). Vector leitet diese jedoch sofort an Loki weiter. Nur `/var/lib/loki` und `/var/lib/grafana` liegen persistent auf der SSD, um historischen Zugriff über Reboots hinweg zu sichern.

---

## 🛡️ Teil 4: CrowdSec & nftables Integration

CrowdSec dient als proaktives Intrusion Detection & Prevention System.

### Funktionsweise
1. **Scannen**: CrowdSec analysiert die systemd-journal-Streams für `sshd.service` und `caddy.service`.
2. **Erkennung**: Bei Brute-Force-Angriffen oder unbefugten Login-Versuchen wird die IP des Angreifers lokal über die LAPI gesperrt.
3. **Bouncer**: Der CrowdSec nftables-Bouncer erhält die gesperrten IPs und blockiert diese sofort auf Paketebene in der nftables-Eingangs-Kette (`input` in `inet filter`).

---

## 🛠️ Operational Procedures & Diagnostics

### Status- und Healthcheck-Verifikationen
```bash
# 1. Gatus, Vector, Loki und Grafana auf Aktivität prüfen
systemctl status gatus.service vector.service loki.service grafana.service

# 2. CrowdSec und nftables Bouncer prüfen
systemctl status crowdsec.service crowdsec-firewall-bouncer.service

# 3. Aktiven Blockierstatus im nftables-Set einsehen
sudo nft list set inet filter crowdsec_blocked_ipv4

# 4. Logs des Vector-Scrapers live verfolgen
journalctl -u vector -f
```
