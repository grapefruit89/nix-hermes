# GEMINI.md – Die Master-Verfassung (v14.0)
# Status: MODERNIZED 10-DOMAIN MODEL & SSoT DATABASE | Stand: Mai 2026
# [SUPERSEDED]: v13.0, v12.0, v11.0, v10.0, v7.0
# ADR-040: LAW OF ASSOCIATIVE MINING – AKTIV
# AKINATOR-PROTOCOL: AKTIV

---

## 0. SPATIAL MAP: DIE TOPOGRAPHIE DER SOUVERÄNITÄT (10-DOMAIN MODEL)

Die gesamte Konfiguration und Dokumentation ist in 10 logische Domänen aufgeteilt, die jeweils ein NixOS-Modul (`modules/`), ein ADR (`ADR/`) und einen operativen Guide (`Guides/`) besitzen:

### 🏗️ Die Werkstatt (Nix Files/modules/) & Das Gehirn (ADR/ & Guides/)
- **00-core:** System-Subsysteme, Kernel Slimming, ZRAM-Swap, Store Tuning.
- **10-network:** AdGuard Home, Valkey (Redis-Fork), PostgreSQL-SSD-Performance.
- **20-security:** Sovereign Remote initrd Unlock (TPM2/Tang/FIDO2/SSH), sops-nix, Zero-Trust SSHD.
- **30-storage:** Disk Mounting, MergerFS Poolings und Tiering-Regeln.
- **40-monitoring:** Netdata, Uptime Kuma (System-Watchtower).
- **50-media:** iGPU-Berechnungen (Intel UHD 630 QSV), Jellyfin und der Arr-Stack (Sonarr, Radarr, Readarr, Prowlarr, Jellyseerr, SABnzbd).
- **60-apps:** Vaultwarden, deklariertes Homepage-Dashboard (Mäusekino) mit Caddy Gateway.
- **70-forge:** Git Server, CI/CD-Pipelines und Automatisierungen.
- **80-gaming:** Deklarierte Game-Server-Instanzen.
- **90-policy:** Systemweite Governance, Assertions, Port-Registrierung.
- **_Templates:** Vorlagen und Blaupausen für neue Module, ADRs, Guides und User-Home-Konfigurationen.

### 📊 Single Source of Truth (SSoT) Databases
- **nixos_docs.db:** Relationale SQLite-Dokumenten-Datenbank mit FTS5-Volltextsuche für blitzschnelles MCP-Wissensabfragen. **[SSoT-Index-Gesetz]:** Die physischen Quelldateien (Nix-Files, ADRs, Guides, Templates) sind das autoritative Master-Medium und werden versioniert. Diese Datenbank dient als maschineller Master-Index für LLM-MCP-Abfragen und wird bei jedem Commit automatisch neu generiert. Templates sind mit dem Status `template` und dem Tag `template` indiziert.
- **memdb.db:** Semantische LLM-Wissensdatenbank (via `@j0hanz/memdb`), die ADRs, Guides und Templates als vernetzte Dokumenten-Erinnerungen (Memories) und Beziehungs-Graphen abspeichert.

---

## I. DER VEREDELUNGS-PROZESS: DIE DREI STUFEN DES GOLDES

Wissen darf NIEMALS gelöscht werden. Es durchläuft einen Zyklus der Reinigung:

1. **STAGE 1 (Roh-Erz):** Unsortierte Snippets, Chat-Logs, Internet-Funde in der legacy Müllhalde (`C:\Users\morit\NixOS\__Müllhalde\`).
2. **STAGE 2 (Nuggets):** Ausgesiebte Fakten im Obsidian-Verzeichnis. Strukturierte ADRs und technische Guides.
3. **STAGE 3 (Goldbarren):** Der refaktorisierte, modularisierte Nix-Code in der Werkstatt, gekoppelt mit der relationalen und semantischen SSoT-Datenbank.

---

## II. ADR-040: GESETZ DES ASSOZIATIVEN MININGS

Ein technischer Term (Seed) ist niemals isoliert. Du MUSS rekursiv suchen:
- **Seed: Storage** → Satellites: SSD/NVMe fast-tier, POSIX lock Compliance, MergerFS epmfs Policy, impermanente persistent-state Bindung.
- **Seed: VPN** → Satellites: SABnzbd Kill-Switch (RestrictNetworkInterfaces = [ "lo" "privado" ]), DNS-Leak Schutz (DNSSERVERS), systemd.services Bindungen.
- **Unterlassung führt zu Systemverstoß.**

---

## III. DER AKINATOR-MODUS (ANFORDERUNGS-ANALYSE)

Wenn ein Ziel unklar definiert ist, ist Raten STRENGSTENS VERBOTEN.
- Starte das interaktive Lastenheft.
- Stelle fokussierte technische Einzelfragen.
- Baue erst das Lastenheft, dann schreibe Nix-Code.

---

## IV. TECHNISCHE KERN-MANDATE (SSoT)

### 💾 Storage & Portabilität
- **ISO-Standard:** Nur Device-Labels (`DISK_SYSTEM`, `DISK_CACHE`, `DISK_STORAGE_*`). Keine Bus-Pfade.
- **Atomic Move Law:** MergerFS Policy `epmfs` ist zwingend. Zero-copy Moves zwischen Tier B (NVMe/SSD Cache) und Tier C (HDDs) via Verzeichnis-Symmetrie.
- **Data Integrity:** PostgreSQL und SQLite müssen ausnahmslos auf SSD/NVMe-Btrfs (`/data/state/`) mit POSIX Lock Support liegen, getrennt von mergerfs.

### 🛡️ Security Vault
- **Stateless Bootstrap:** Impermanentes System (tmpfs auf `/`). Alle Keys werden beim Booten via transientem USB-Hardware-Anchor (TPM2-entriegelt) temporär geladen und sofort ungemountet.
- **UDS-Gesetz:** Caddy ↔ Backend-Kommunikation bevorzugt via Unix Domain Sockets (UDS) für minimale Latenz und maximale Isolation. Für Programme ohne native UDS-Unterstützung (wie Radarr, Sonarr, SABnzbd) gilt localhost-TCP als deklarierter Standard-Fallback.
- **Secrets:** Strikte `sops-nix` Purity. Keine Secrets im Nix-Store oder in Git-Commits.

### 📊 Datenbanken & SSoT-Sync (SSoT Index Law)
- **Database SSoT Index:** Die physischen Quelldateien sind die autoritative Quelle für Menschen und werden im Git-Repository versioniert. Die relationale `nixos_docs.db` ist das Master-Führungsmedium für maschinelle LLM-Abfragen.
- **Forward-Sync Mandat:** Bei jeder Dateiänderung und jedem Git-Commit wird die Datenbank per `build_dbs.py` automatisch neu aus den physischen Dateien generiert (Forward-Sync), um einen konsistenten Wissenszustand für LLM-Agenten zu garantieren.

### ⚔️ Antipattern-Verbot (Zero Tolerance)
Jede KI, die im Auftrag dieses Repositories arbeitet, MUSS vor der Implementierung eines Dienstes, einer Architektur oder eines Tools zwingend die Antipattern-Dokumentation in der SSoT-Datenbank konsultieren:
`SELECT * FROM documents WHERE status = 'antipattern';`
Es ist strengstens verboten, deklarierte Antipatterns (z. B. Thymis, Kopia, Global Firewall Disabling, legacy iptables, ephemeral logs, auxiliary socat proxies) wieder einzuführen. Ein Verstoß gilt als kritischer Systemfehler und führt zur sofortigen Ablehnung der Code-Generierung.

### 🔄 Closed-Loop Workflow
- Jeder `git commit` triggert automatisch `tools/build_dbs.py` und `tools/validate_ssot.py` via Pre-Commit-Hook.
- Deployment erfolgt ausschließlich über `tools/nixdeploy.ps1` (oder manuell mit vorangestelltem DB-Sync).
- `nixos_docs.db` bleibt durch mechanische Hooks das autoritative maschinelle Wissen der LLM-Agenten.
- Keine menschenlesbaren Reports; alle stakeholders sind LLMs.

### ✅ Validierungsregeln
- ADR-Status: nur `proposed`, `accepted`, `deprecated`, `superseded`.
- Keine Platzhalter-Status (keine Rohlinge aus Templates in der DB).
- Alle referenzierten Pfade (Guides, Module) müssen existieren.
- NIXMETA-Blöcke sind für alle Nix-Module verpflichtend und müssen alle Felder (domain, id, status, provides, requires) korrekt deklarieren.
- `ref.code`-Bindung in ADRs wird empfohlen (wie NMS), aber nicht enforced.

### 📂 `.temp_workfolder` – Temporäre Arbeitsdateien
Alle einmaligen Berichte, Audit-Ergebnisse, temporären Skripte und Notizen, die im Laufe der Projektarbeit entstehen, werden ausschliesslich in diesem Ordner abgelegt.
- **Keine** dieser Dateien wird in die SSoT-Datenbank (`nixos_docs.db`) oder (`memdb.db`) importiert (die Datenbank-Compiler ignorieren standardmäßig alle Verzeichnisse, die mit einem Punkt beginnen).
- Die Informationen daraus sind bereits in den regulären Modulen, ADRs oder Guides umgesetzt.
- Der Ordner dient als persönliches Arbeitsjournal und muss nicht versioniert werden.
- KIs, die im Projekt arbeiten, dürfen diesen Ordner lesen (um Kontext zu verstehen), aber **niemals** seine Inhalte in die Datenbank schreiben oder als autoritative Quelle verwenden.

---

## V. RECONCILIATION LOG
- **v14.2:** Anpassung der SSoT-Regeln (Dateien sind Master, DB ist maschineller Index) für den pragmatischen Entwicklungsmodus.
- **v14.1:** Verankerung des Database-Master SSoT und des Reverse-Sync Mandats in der Verfassung.
- **v14.0:** Umstellung auf das saubere, deklarierte 10-Domain-Modell.
- **FTS5 Integration:** Aktivierung der Volltext-Suche in der relationalen Datenbank.
- **Semantic Memory:** Kopplung an den `@j0hanz/memdb` Server für Graph-basiertes LLM-Wissen.
