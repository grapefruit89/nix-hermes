---
title:        "ADR-32: Architekturentscheidung: Kein Thymis für das Homelab"
domain:       90
folder:       90-policy
status:       accepted
date:         2026-06-03
deciders:     [moritz]
review_after: 2027-06-03
links:
  guide:   ANTIPATTERNS.md
  modules: []
  supersedes: []
---

# ADR-32: Architekturentscheidung: Kein Thymis für das Homelab

> **Wir entscheiden uns gegen den Einsatz von Thymis (oder ähnlichen NixOS-Flottenmanagement-Werkzeugen) zur Verwaltung unseres einzelnen Homelab-Servers. Thymis ist für das Management verteilter Geräteflotten konzipiert. Die Einführung auf einem einzelnen Standalone-Server erzeugt unnötige Komplexität, erhöht die Angriffsfläche und bietet keinen funktionalen Mehrwert gegenüber unserem rein deklarativen Flake- und GitOps-basierten lokalen Build-Workflow.**

---

## Kontext

**Was ist das Problem?**
Wir untersuchen kontinuierlich Werkzeuge zur Optimierung der Systembereitstellung und -verwaltung auf unserem Fujitsu Q958 Server. Ein potenzieller Kandidat ist **Thymis**, ein Tool zur Orchestrierung und Bereitstellung von NixOS-Systemkonfigurationen.
Allerdings betreiben wir ein extrem fokussiertes Setup:
1. **Ein-Server-Infrastruktur:** Wir verwalten genau ein primäres Homelab-System (Fujitsu Q958) und keinen verteilten Geräte-Park.
2. **Deklarative Reinheit:** Unsere Konfigurationen sind bereits vollständig modularisiert (10-Domain-Modell) und werden über Flakes deklariert.
3. **Stateless Bootstrap:** Wir nutzen ein impermanentes System (`tmpfs` auf `/`), bei dem der Systemzustand nach jedem Neustart deterministisch neu aufgebaut wird.

---

## Betrachtete Alternativen

### Option A: Lokaler Flake-basierter Build-Workflow ← GEWÄHLT

**Was es ist:**
Wir verwalten unsere NixOS-Konfiguration direkt in einem Git-Repository unter Nutzung von Nix-Flakes. Deployments werden lokal mit `nixos-rebuild switch --flake .#host` ausgeführt. Secrets werden mittels `sops-nix` dezentral verschlüsselt.

**Vorteile:**
- **Zero Overhead:** Keine zusätzlichen Daemons, Agenten oder Datenbanken erforderlich.
- **Minimale Angriffsfläche:** Kein offener Control-Plane-Port oder externer SSH-Pull/Push-Agent für die Systempflege nötig.
- **Volle Kontrolle:** Alle Build-Vorgänge laufen direkt und nachvollziehbar auf dem Zielsystem.

**Nachteile:**
- Keine zentrale GUI zur Verwaltung mehrerer Hosts (für unser Ein-Server-Setup irrelevant).

---

### Option B: Orchestrierung über Thymis ← ABGELEHNT

**Was es ist:**
Einsatz von Thymis zur deklarativen Erfassung, Verteilung und Überwachung der NixOS-Konfiguration.

**Warum abgelehnt:**
- **Flotten-Fokus:** Thymis ist für das Management ganzer Flotten (z. B. Edge-Geräte, IoT-Nodes oder verteilte Server) konzipiert.
- **Overengineering:** Für ein einzelnes System fügt Thymis eine zusätzliche Orchestrierungsschicht hinzu, die den Deployment-Workflow verkompliziert.
- **Sicherheitsrisiko:** Es erfordert zusätzliche privilegierte Kommunikationskanäle (Agenten/SSH-Zugriffe) auf dem Server.
- **Workflow-Komplexität:** Der direkte Weg über Git und Flakes wird unnötig verschachtelt.

---

## Entscheidung

**Wir wählen Option A.**

Wir deklarieren:
1. Wir verzichten auf Thymis und ähnliche Flotten-Manager (z. B. Morph, Colmena, binfmt-basierte Remote-Builder), solange wir nur einen einzelnen Host betreiben.
2. Unser lokaler Flake-Workflow bleibt die einzige Quelle der Wahrheit (Single Source of Truth).
3. Wir führen Thymis als offizielles Antipattern für Standalone-Homelabs auf.

---

## Validierung

- **Signal:** Systemänderungen werden direkt über Flakes/rebuild deklariert und eingepflegt. Die Komplexität des Deployments bleibt minimal.
- **Überprüfungsfrequenz:** Bei Hinzufügen weiterer physischer Server (Flotten-Wachstum).
