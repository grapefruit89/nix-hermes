# @meta -------------------------------------------------
# type:       host-config
# status:     active
# ------------------------------------------------------
# PURPOSE: System-Level Configuration für diese spezifische Maschine.
# Hier kommen Hostname, Bootloader und Hardware-spezifische Services rein.

{ config, pkgs, lib, ... }:

{
  # --- Imports ---
  imports = [
    ./hardware-nixos.nix
  ];

  # --- Boot & Hardware ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # --- Networking ---
  # networking.hostName = "laptop"; 

  # --- State ---
  system.stateVersion = "23.11";
}
