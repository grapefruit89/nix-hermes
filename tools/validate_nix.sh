#!/usr/bin/env bash
set -euo pipefail

export NIXPKGS_ALLOW_UNFREE=1
NIX_BIN="/nix/var/nix/profiles/default/bin/nix"
FLAKE_PATH="/mnt/c/Users/morit/Documents/Obsidian_Main/NixOS/Nix Files"

echo ">> Running nixpkgs-fmt check..."
$NIX_BIN shell nixpkgs#nixpkgs-fmt -c nixpkgs-fmt --check "$FLAKE_PATH"

echo ">> Running statix check..."
$NIX_BIN shell nixpkgs#statix -c statix check "$FLAKE_PATH"

echo ">> Running deadnix check..."
$NIX_BIN shell nixpkgs#deadnix -c deadnix "$FLAKE_PATH"
