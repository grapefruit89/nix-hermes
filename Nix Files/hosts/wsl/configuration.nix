# @spec-kit ---------------------------------------------
# type:       host-config
# status:     active
# id:         NIXH-HOST-WSL
# title:      "Host Configuration: NixOS inside WSL"
# complexity: 3
# description: "System configuration for running the NixOS development environment inside WSL."
# ------------------------------------------------------

{ config, pkgs, lib, ... }:

{
  # ─── IMPORTS ────────────────────────────────────────────────────────────────
  # Imports the hardware profile and all 10 domain flat modules.
  imports = [
    ../../modules/00-core.nix
    ../../modules/10-network.nix
    ../../modules/15-firewall.nix
    ../../modules/20-security.nix
    ../../modules/30-storage.nix
    ../../modules/35-automount.nix
    ../../modules/40-observability.nix
    ../../modules/50-media
    ../../modules/60-apps
    ../../modules/70-forge.nix
    ../../modules/80-gaming.nix
    ../../users/moritz/default.nix
  ];

  # ─── WSL SPECIFIC CONFIG ──────────────────────────────────────────────────
  wsl = {
    enable = true;
    defaultUser = "moritz";
  };

  # Set initial passwords in development mode to prevent lockout
  users.users.moritz.initialPassword = "nixos123";
  users.users.root.initialPassword = "nixos123";

  # ─── HOME MANAGER INTEGRATION ───────────────────────────────────────────────
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.moritz = import ../../users/moritz/home.nix;
  };

  # ─── IDENTITY & LOCALE ──────────────────────────────────────────────────────
  my = {
    configs = {
      identity = {
        user = "moritz";
        domain = "wsl.local";
      };
      hardware = {
        ramGB = 8;
      };
      server = {
        lanIP = "127.0.0.1";
        tailscaleIP = "127.0.0.1";
      };
    };

    # ─── SYSTEM MODE SWITCH ─────────────────────────────────────────────────────
    mode = "development";

    # ─── CORE SYSTEM SERVICES ──────────────────────────────────────────────────
    core = {
      boot-safeguard.enable = false; # Not needed in WSL
      kernel-slim.enable = false; # Not needed in WSL
      nix-tuning.enable = true;
      zram-swap.enable = false; # WSL handles paging
    };

    # ─── NETWORKING & DB SERVICES ────────────────────────────────────────────────
    services = {
      adguardhome.enable = false;
      valkey.enable = true;
      postgresql.enable = true;
      blocky.enable = false;
      tailscale.enable = false; # Disable to avoid conflict with Windows Tailscale
      pocket-id.enable = true;

      # ─── STORAGE SYSTEM ─────────────────────────────────────────────────────────
      storage.enable = false; # Disable mergerfs in WSL
      storage-automount.enable = false;
      gatus.enable = false;
      restic-backup.enable = false;

      # ─── APPLICATION LAYER ──────────────────────────────────────────────────────
      vaultwarden.enable = true;
      homepage.enable = true;
      paperless.enable = true;
      filebrowser.enable = true;
      linkwarden.enable = true;
      open-webui.enable = true;
      hermes.enable = false;

      # Disable IoT and Gaming stacks in WSL
      home-assistant.enable = false;
      zigbee-stack.enable = false;
      semaphore.enable = false;
      amp.enable = false;
    };

    # ─── SECURITY & HARDENING ───────────────────────────────────────────────────
    security = {
      sovereign-unlock.enable = false;
      firewall.enable = false; # Disable nftables inside WSL (needs custom kernel)
      crowdsec.enable = false;
      fail2ban.enable = false;
      dropbear-rescue.enable = true;
    };

    impermanence.enable = false;
    observability.enable = false;
  };

  networking.hostName = "nixos-wsl";

  # ─── SYSTEM STATE VERSION ───────────────────────────────────────────────────
  system.stateVersion = "24.11";
}
