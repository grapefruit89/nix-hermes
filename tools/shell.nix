{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "nixos-db-tools";
  buildInputs = with pkgs; [
    python3
    sqlite
  ];
  shellHook = ''
    echo "NixOS DB Tools Shell"
    echo "Verfügbare Befehle:"
    echo "  python tools/build_dbs.py   # Relationale & Semantische DBs erstellen"
  '';
}
