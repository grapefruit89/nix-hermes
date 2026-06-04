---
title: "Antipattern: Thymis für einen einzelnen NixOS-Server"
status: antipattern
tags: [antipattern, verboten, architecture, management]
---

# 📛 ANTIPATTERN: Thymis für einen einzelnen NixOS-Server

In diesem Dokument wird analysiert, warum der Einsatz von Thymis zur Verwaltung eines einzelnen Standalone-Homelab-Servers ein Antipattern darstellt.

### Das Antipattern: Overengineering durch Flotten-Tools

Thymis ist ein mächtiges Werkzeug zur Bereitstellung, Aktualisierung und Überwachung von NixOS-Systemen. Seine Architektur ist jedoch gezielt auf das **Flottenmanagement** (Flocken von IoT-Geräten, Edge-Infrastrukturen oder Multi-Server-Umgebungen) ausgerichtet. 

Der Einsatz von Thymis für einen einzelnen Homelab-Host führt zu folgendem Fehlverhalten:
1. **Overengineering & Komplexität**: Es wird eine zusätzliche Verwaltungsebene eingeführt, die den Deployment-Zyklus verlängert, ohne funktionalen Nutzen zu bringen.
2. **Sicherheitsrisiko durch zusätzliche Control Planes**: Der Server muss zusätzliche Kanäle für Agenten oder Management-SSH-Zugriffe öffnen, was die Angriffsfläche vergrößert.
3. **Zustandskonflikte**: Auf einem impermanenten Server (tmpfs auf `/`) kollidieren die von externen Management-Tools erwarteten persistenten Laufzeit-Status oft mit der deklarativen zustandslosen Struktur.

### Der empfohlene Pattern: Lokaler Flake-basierter GitOps-Workflow

Für einen einzelnen Server ist das direkte und einfache lokale Deployment der beste Weg:
- **Einfachheit**: Verwendung von `nixos-rebuild switch --flake .#host` direkt auf dem System.
- **GitOps**: Versionierung der Konfiguration in einem Git-Repository. Bei Drift-Erkennung oder Fehlern wird das System einfach neu gebaut oder gebootet.
- **Zero Overhead**: Keine zusätzlichen Daemons oder externen Abhängigkeiten, die ausfallen oder kompromittiert werden können.
