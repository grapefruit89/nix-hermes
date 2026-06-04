# NixOS Repository Database Tools

Dieses Verzeichnis enthält die Werkzeuge zur Erstellung und Aktualisierung der relationalen und semantischen SQLite-Datenbanken (`nixos_docs.db` und `memdb.db`) für das LLM-Wissensmanagement.

## Konzept

Die alten JavaScript-Skripte (`build_db.js`, `build_memdb.js`) und die lokalen `node_modules` wurden vollständig durch einen einheitlichen Python-Compiler (`build_dbs.py`) ersetzt. Das spart Speicherplatz, verhindert Dateichaos und macht Abhängigkeiten überflüssig, da Python und seine native `sqlite3`-Bibliothek standardmäßig FTS5 unterstützen.

## Dateien im Ordner

- **build_dbs.py**: Das Python-Kompilierungsskript, das das Repository scannt, YAML-Frontmatter parst und beide Datenbanken (`nixos_docs.db` und `memdb.db`) direkt aktualisiert.
- **shell.nix**: Eine deklarierte Nix-Shell-Definition für Linux/NixOS-Umgebungen, um Python 3 und SQLite bereitzustellen.
- **sync_dbs.ps1**: PowerShell-Skript zum schnellen Ausführen der Datenbank-Aktualisierung auf Windows.
- **Update_NixOS_DB.ps1**: Ein detailliertes PowerShell-Skript mit formatierten Ausgaben.

## Ausführung

### Unter Windows 11
Führe das PowerShell-Skript aus:
```powershell
powershell -ExecutionPolicy Bypass -File tools/sync_dbs.ps1
```
Alternativ kann das Python-Skript direkt aufgerufen werden:
```powershell
python tools/build_dbs.py
```

### Unter NixOS / Linux
Führe das Skript innerhalb der Nix-Shell aus:
```bash
nix-shell tools/shell.nix --run "python tools/build_dbs.py"
```
Oder betrete die Nix-Shell interaktiv:
```bash
nix-shell tools/shell.nix
python tools/build_dbs.py
exit
```
