# @meta -------------------------------------------------
# type:       user-home-config
# status:     active
# ------------------------------------------------------
# PURPOSE: Home-Manager Konfiguration.
# Hier kommen Dotfiles, User-spezifische Pakete und CLI-Tool-Configs rein.

{ config, pkgs, ... }:

{
  home = {
    username = "freund";
    homeDirectory = "/home/freund";

    # --- User Packages ---
    packages = with pkgs; [
      htop
      git
      # ... weitere CLI Tools
    ];

    stateVersion = "23.11";
  };

  # --- Program Configs ---
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "freund";
        email = "freund@example.com";
      };
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
