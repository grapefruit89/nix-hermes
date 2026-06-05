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

  networking.hostName = "q958";
  networking.networkmanager.enable = true;

  # ─── IDENTITY & LOCALE ──────────────────────────────────────────────────────
  my = {
    configs = {
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

    core = {
      boot-safeguard.enable = true;
      kernel-slim.enable = true;
      nix-tuning.enable = true;
      zram-swap.enable = true;
    };

    mode = "development";

    services = {
      adguardhome.enable = false;
      valkey.enable = true;
      postgresql.enable = true;
      blocky.enable = true;
      tailscale.enable = true;
      pocket-id.enable = true;

      storage = {
        enable = true;
        poolMountPoint = "/mnt/media";
      };

      storage-automount.enable = true;
      gatus.enable = true;

      restic-backup = {
        enable = true;
        healthcheckUrl = "https://hc-ping.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
      };

      jellyfin.enable = true;
      jellyseerr.enable = true;
      sonarr.enable = true;
      radarr.enable = true;
      readarr.enable = true;
      prowlarr.enable = true;
      sabnzbd.enable = true;

      vaultwarden.enable = true;
      homepage.enable = true;
      paperless.enable = true;
      n8n.enable = false;
      filebrowser.enable = true;
      linkwarden.enable = true;
      open-webui.enable = true;
      hermes.enable = true;

      # Home Automation & IoT Integration (Mined from External GitHub Repositories Phase 2)
      home-assistant = {
        enable = true;
        port = 8123;
        zigbeeDevice = "socket://192.168.1.100:6638"; # SLZB-06 socket connection
      };

      zigbee-stack = {
        enable = true;
        mqttPort = 1883;
        zigbeePort = 8075;
        zigbeeDevice = "socket://192.168.1.100:6638"; # SLZB-06 socket connection
        adapter = "ember"; # Modern Ember driver for SLZB-06 coordinator
      };

      semaphore.enable = true;
      amp.enable = true;
    };

    security = {
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

    impermanence = {
      persistentDisk = "/dev/disk/by-label/NIXHOME_PERSIST";
      persistMountPoint = "/persist";
    };

    observability.enable = true;
  };

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = [ "i915.enable_guc=2" ];
  };

  # ─── SYSTEM STATE VERSION ───────────────────────────────────────────────────
  system.stateVersion = "24.11";
}
