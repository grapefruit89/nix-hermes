Set-Location -Path "C:\Users\morit\Documents\Obsidian_Main\NixOS"
Write-Output "Running build_dbs.py..."
python tools/build_dbs.py
if ($LASTEXITCODE -ne 0) {
    Write-Error "build_dbs.py failed"
    exit $LASTEXITCODE
}
Write-Output "Database sync completed successfully!"
