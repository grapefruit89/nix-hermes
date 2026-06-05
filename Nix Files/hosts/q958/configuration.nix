# @meta -------------------------------------------------
# type:       host-config
# status:     active
# id:         NIXH-HOST-Q958
# title:      "Host Configuration: Fujitsu Q958 Server"
# complexity: 3
# reviewed:   2026-05-26
# description: "System-level configuration for the headless home server. Connects all flat modules."
# ------------------------------------------------------

{ config, pkgs, lib, ... }:

{
  # ─── IMPORTS ────────────────────────────────────────────────────────────────
  # Imports the hardware profile and all 10 domain flat modules.
  imports = [
    ./hardware-nixos.nix
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
      domain = "m7c5.de";
    };
    hardware = {
      ramGB = 32;
    };
    server = {
      lanIP = "192.168.1.100";
      tailscaleIP = "100.64.0.1";
    };
  };

  networking.hostName = "q958";
  networking.hostId = "deadbeef";
  networking.networkmanager.enable = true;

  # ─── DOMAIN 00: CORE SYSTEM SERVICES ───────────────────────────────────────
  my.core = {
    boot-safeguard.enable = true;
    kernel-slim.enable = true;
    nix-tuning.enable = true;
    zram-swap.enable = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "i915.enable_guc=2" ];

  # --- GLOBAL SYSTEM FONTS (Eliminates Jellyfin Subtitle Tofu & Burn-in Crashes) ---
  fonts.packages = with pkgs; [
    dejavu_fonts
    liberation_ttf
    freefont_ttf
    noto-fonts
    noto-fonts-cjk-sans
  ];

  # ─── DOMAIN 10: NETWORKING & SYSTEM DATABASES ────────────────────────────────
  my.services = {
    adguardhome.enable = false;
    valkey.enable = true;
    postgresql.enable = true;
    blocky.enable = true;
    tailscale.enable = true;
    pocket-id.enable = true;
  };

  # ─── SYSTEM MODE SWITCH ─────────────────────────────────────────────────────
  my.mode = "development";

  # ─── DOMAIN 20: SECURITY & HARDENING ────────────────────────────────────────
  my.security = {
    sovereign-unlock = {
      luksDevice = "/dev/disk/by-label/NIXHOME_CRYPT";
      sshPort = 2222;
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJRDbyFjT4SEL8yxNwZuEBPORD82qlJJhdr2r4qz1vCX"
      ];
    };
    firewall.enable = true;
    crowdsec.enable = true;
    fail2ban.enable = true;
    dropbear-rescue.enable = true;
  };

  # ─── DOMAIN 30: STORAGE SYSTEM ──────────────────────────────────────────────
  my.impermanence = {
    persistentDisk = "/dev/disk/by-label/NIXHOME_PERSIST";
    persistMountPoint = "/persist";
  };

  my.services.storage = {
    enable = true;
    poolMountPoint = "/mnt/media";
  };

  my.services.storage-automount.enable = true;

  my.services.gatus.enable = true;
  my.observability.enable = true;

  my.services.restic-backup = {
    enable = true;
    healthcheckUrl = "https://hc-ping.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
  };

  # Ephemeral stateless root tmpfs definition is declared dynamically in 30-storage.nix if my.impermanence.enable is true.
  # During development (non-impermanent root), we rely on hardware-nixos.nix's ext4 root definition.

  # ─── DOMAIN 50: UNIFIED MEDIA ENGINE ─────────────────────────────────────────
  my.services = {
    jellyfin.enable = true;
    jellyseerr.enable = true;
    sonarr.enable = true;
    radarr.enable = true;
    readarr.enable = true;
    prowlarr.enable = true;
    sabnzbd.enable = true;
  };

  # ─── DOMAIN 60: PRODUCTION APPLICATION LAYER ─────────────────────────────────
  my.services.vaultwarden.enable = true;
  my.services.homepage.enable = true;
  my.services.paperless.enable = true;
  my.services.n8n.enable = false;
  my.services.filebrowser.enable = true;
  my.services.linkwarden.enable = true;
  my.services.open-webui.enable = true;
  my.services.hermes.enable = true;

  # Home Automation & IoT Integration (Mined from External GitHub Repositories Phase 2)
  my.services.home-assistant = {
    enable = true;
    port = 8123;
    zigbeeDevice = "socket://192.168.1.100:6638"; # SLZB-06 socket connection
  };

  my.services.zigbee-stack = {
    enable = true;
    mqttPort = 1883;
    zigbeePort = 8075;
    zigbeeDevice = "socket://192.168.1.100:6638"; # SLZB-06 socket connection
    adapter = "ember"; # Modern Ember driver for SLZB-06 coordinator
  };

  # ─── DOMAIN 70: FORGE & MANAGEMENT ──────────────────────────────────────────
  my.services.semaphore.enable = true;

  # ─── DOMAIN 80: GAMING ──────────────────────────────────────────────────────
  my.services.amp.enable = true;

  # ─── SYSTEM STATE VERSION ───────────────────────────────────────────────────
  system.stateVersion = "24.11";
}
