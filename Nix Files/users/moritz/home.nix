# @meta -------------------------------------------------
# type:       user-home-config
# status:     active
# ------------------------------------------------------
# PURPOSE: Home-Manager Konfiguration.
# Hier kommen Dotfiles, User-spezifische Pakete und CLI-Tool-Configs rein.

{ config, osConfig, pkgs, ... }:

{
  home = {
    username = "moritz";
    homeDirectory = "/home/moritz";

    # --- User Packages ---
    packages = with pkgs; [
      htop
      git
      # ... weitere CLI Tools
    ];

    # --- Environment Locale Bindings ---
    sessionVariables = {
      LANG = osConfig.my.configs.locale.default;
      LC_ALL = osConfig.my.configs.locale.default;
    };

    stateVersion = "23.11";
  };

  # --- Program Configs ---
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "moritz";
        email = "moritz@example.com";
      };
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
