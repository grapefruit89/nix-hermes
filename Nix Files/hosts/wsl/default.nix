# @meta -------------------------------------------------
# type:       host-config-wrapper
# status:     active
# ------------------------------------------------------
# PURPOSE: Host-spezifische Initialisierung für WSL.

{ ... }:

{
  imports = [
    ./configuration.nix
  ];
}
