#!/usr/bin/env python3
"""SSOT-Validator fuer NixOS-Projekt (LLM-first).
Prueft Konsistenz zwischen ADRs, Nix-Modulen und der relationalen Datenbank.
Blockiert den Commit bei Verstoss gegen Pflichtregeln."""

import os, re, sys, sqlite3
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
DB_PATH = BASE / "nixos_docs.db"

errors = []
warnings = []

# 1) Erlaubte ADR-Status (laut Template und GEMINI.md)
ADR_STATUSES = {"proposed", "accepted", "deprecated", "superseded"}

# 2) Bekannte Domains (00-core .. 90-policy)
KNOWN_DOMAINS = {
    "00-core", "10-network", "20-security", "30-storage", "35-automount",
    "40-observability", "50-media", "60-apps", "70-forge", "80-gaming", "90-policy"
}

def check_adrs():
    """Prueft ADR-Frontmatter: Status-Werte, Platzhalter, referenzierte Pfade."""
    adr_dir = BASE / "ADR"
    if not adr_dir.exists():
        return []
    ids = set()
    for p in sorted(adr_dir.glob("*.md")):
        if p.name in {"README.md", "Gemini.md"}:
            continue
        text = p.read_text(encoding="utf-8", errors="ignore")
        fm = {}
        if text.startswith("---"):
            parts = text.split("---", 2)
            if len(parts) >= 3:
                for line in parts[1].splitlines():
                    if ":" in line:
                        k, v = line.split(":", 1)
                        fm[k.strip().lower()] = v.strip()
        status = fm.get("status", "")
        if status:
            base = status.split()[0].strip()
            if base not in ADR_STATUSES:
                errors.append(
                    f"ADR {p.name}: unerlaubter Status '{status}' "
                    f"(erlaubt: {sorted(ADR_STATUSES)})"
                )
            if base == "superseded":
                target = status.split("superseded-by:", 1)[-1].strip()
                if not target:
                    errors.append(
                        f"ADR {p.name}: Status 'superseded' ohne Zielangabe "
                        f"(fehlt 'superseded-by:ADR-YY')."
                    )
                else:
                    if not (adr_dir / target).exists():
                        errors.append(
                            f"ADR {p.name}: Ziel-ADR '{target}' existiert nicht."
                        )
        m = re.search(r"ADR[-\s]?(\d+)", p.name)
        if m:
            adr_num = m.group(1)
            if adr_num in ids:
                errors.append(f"ADR {p.name}: doppelte Nummer ADR-{adr_num}")
            ids.add(adr_num)
        links_raw = fm.get("links", "{}")
        try:
            links = __import__("ast").literal_eval(links_raw) if links_raw.startswith("{") else {}
        except Exception:
            links = {}
        for key in ("guide",):
            val = links.get(key, "")
            if val and not (BASE / val).exists():
                errors.append(f"ADR {p.name}: referenzierter Guide '{val}' existiert nicht")
        modules_raw = links.get("modules", "[]")
        try:
            modules = __import__("ast").literal_eval(modules_raw) if isinstance(modules_raw, str) else modules_raw
        except Exception:
            modules = []
        if isinstance(modules, str):
            modules = [modules]
        for mod in modules:
            if mod and not (BASE / mod).exists():
                errors.append(f"ADR {p.name}: referenziertes Modul '{mod}' existiert nicht")
    return []

def check_nix_modules():
    """Prueft NIXMETA-Block: Pflicht in jedem Modul, valide Domain, 4 Pflichtfelder."""
    mod_dir = BASE / "Nix Files" / "modules"
    if not mod_dir.exists():
        return []
    # Scan recursively using rglob to check modular folders
    for p in sorted(mod_dir.rglob("*.nix")):
        text = p.read_text(encoding="utf-8", errors="ignore")
        if "---NIXMETA---" not in text:
            errors.append(
                f"Modul {p.name}: fehlt NIXMETA-Block "
                f"(Pflicht fuer maschinelle Verarbeitung)."
            )
            continue
        m = re.search(r"domain:\s*(\S+)", text)
        if not m:
            errors.append(
                f"Modul {p.name}: NIXMETA-Feld 'domain' fehlt oder ist leer."
            )
            continue
        domain = m.group(1)
        if domain not in KNOWN_DOMAINS:
            errors.append(
                f"Modul {p.name}: unbekannte Domain '{domain}' "
                f"(erlaubt: {sorted(KNOWN_DOMAINS)})."
            )
        for field in ["id", "status", "provides", "requires"]:
            if not re.search(rf"{field}:\s*\S+", text):
                errors.append(
                    f"Modul {p.name}: NIXMETA-Feld '{field}' fehlt (Pflicht)."
                )
    return []

def check_db_quality():
    """Prueft DB-Inhalte: keine Platzhalter-Status (Template-Rohlinge)."""
    if not DB_PATH.exists():
        errors.append(f"Datenbank {DB_PATH} nicht gefunden.")
        return []
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()
    cur.execute("SELECT path, status FROM documents;")
    for path_, status in cur.fetchall():
        if not status:
            continue
        if any(tok in status for tok in ["XX", "Template", "placeholder"]):
            errors.append(
                f"DB-Eintrag {path_}: Status ist Platzhalter ('{status}'). "
                f"Bitte mit echten Werten fuellen."
            )
    con.close()
    return []

def main():
    print(">> Validiere SSOT-Projektstruktur (LLM-first)...")
    check_adrs()
    check_nix_modules()
    check_db_quality()
    if errors:
        print(f"\n[FAIL] {len(errors)} Fehler gefunden:")
        for e in errors:
            print(f"  - {e}")
    if warnings:
        print(f"\n[WARNING] {len(warnings)} Warnungen:")
        for w in warnings:
            print(f"  - {w}")
    if not errors and not warnings:
        print(">> Alles sauber.")
    if errors:
        sys.exit(1)

if __name__ == "__main__":
    main()
