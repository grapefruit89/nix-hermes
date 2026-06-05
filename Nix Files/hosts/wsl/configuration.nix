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
  my.configs = {
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

  networking.hostName = "nixos-wsl";

  # ─── SYSTEM MODE SWITCH ─────────────────────────────────────────────────────
  my.mode = "development";

  # ─── CORE SYSTEM SERVICES ──────────────────────────────────────────────────
  my.core = {
    boot-safeguard.enable = false; # Not needed in WSL
    kernel-slim.enable = false; # Not needed in WSL
    nix-tuning.enable = true;
    zram-swap.enable = false; # WSL handles paging
  };

  # ─── NETWORKING & DB SERVICES ────────────────────────────────────────────────
  my.services = {
    adguardhome.enable = false;
    valkey.enable = true;
    postgresql.enable = true;
    blocky.enable = false;
    tailscale.enable = false; # Disable to avoid conflict with Windows Tailscale
    pocket-id.enable = true;
  };

  # ─── SECURITY & HARDENING ───────────────────────────────────────────────────
  my.security = {
    sovereign-unlock.enable = false;
    firewall.enable = false; # Disable nftables inside WSL (needs custom kernel)
    crowdsec.enable = false;
    fail2ban.enable = false;
    dropbear-rescue.enable = true;
  };

  # ─── STORAGE SYSTEM ─────────────────────────────────────────────────────────
  my.impermanence.enable = false;
  my.services.storage.enable = false; # Disable mergerfs in WSL
  my.services.storage-automount.enable = false;
  my.services.gatus.enable = false;
  my.observability.enable = false;
  my.services.restic-backup.enable = false;

  # ─── APPLICATION LAYER ──────────────────────────────────────────────────────
  my.services.vaultwarden.enable = true;
  my.services.homepage.enable = true;
  my.services.paperless.enable = true;
  my.services.filebrowser.enable = true;
  my.services.linkwarden.enable = true;
  my.services.open-webui.enable = true;
  my.services.hermes.enable = false;

  # Disable IoT and Gaming stacks in WSL
  my.services.home-assistant.enable = false;
  my.services.zigbee-stack.enable = false;
  my.services.semaphore.enable = false;
  my.services.amp.enable = false;

  # ─── SYSTEM STATE VERSION ───────────────────────────────────────────────────
  system.stateVersion = "24.11";
}
