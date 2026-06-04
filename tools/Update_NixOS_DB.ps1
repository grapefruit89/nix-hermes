# Update_NixOS_DB.ps1 - Automatisches Update der NixOS SQLite-Datenbanken
# Erstellt für das LLM-first Hybrid-Modell

$ErrorActionPreference = "Stop"
$NixOSDir = "C:\Users\morit\Documents\Obsidian_Main\NixOS"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  NixOS SQLite-Datenbank Compiler (Python)" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $NixOSDir)) {
    Write-Error "NixOS-Verzeichnis nicht gefunden unter: $NixOSDir"
    Exit 1
}

# In das NixOS-Verzeichnis wechseln
Set-Location -Path $NixOSDir

Write-Host "Scanne Verzeichnis und erstelle relationale und semantische Datenbanken..." -ForegroundColor Yellow
try {
    python tools/build_dbs.py
} catch {
    Write-Error "Fehler beim Ausführen von tools/build_dbs.py. Vergewissere dich, dass Python 3 installiert ist."
    Exit 1
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " SUCCESS: NixOS SQLite-Datenbanken aktualisiert!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
