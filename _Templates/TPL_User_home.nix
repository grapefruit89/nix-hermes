# @meta -------------------------------------------------
# type:       user-home-config
# status:     active
# ------------------------------------------------------
# PURPOSE: Home-Manager Konfiguration.
# Hier kommen Dotfiles, User-spezifische Pakete und CLI-Tool-Configs rein.

{ config, pkgs, ... }:

{
  home.username = "REPLACE_USER";
  home.homeDirectory = "/home/REPLACE_USER";

  # --- User Packages ---
  home.packages = with pkgs; [
    htop
    git
    # ... weitere CLI Tools
  ];

  # --- Program Configs ---
  programs.git = {
    enable = true;
    userName = "REPLACE_USER";
    userEmail = "REPLACE_USER@example.com";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  home.stateVersion = "23.11";
}