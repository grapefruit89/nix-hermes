#!/usr/bin/env pwsh
param(
    [string]$FlakeTarget = ".#q958"
)

Set-Location $PSScriptRoot\..
Write-Host ">> Aktualisiere SSoT-Datenbank..."
python tools/build_dbs.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Datenbank-Sync fehlgeschlagen. Deployment abgebrochen."
    exit 1
}
Write-Host ">> Validiere strukturelle Konsistenz..."
python tools/validate_ssot.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "Validierung fehlgeschlagen. Deployment abgebrochen."
    exit 1
}
Write-Host ">> Starte NixOS-Rebuild..."
nixos-rebuild switch --flake $FlakeTarget
