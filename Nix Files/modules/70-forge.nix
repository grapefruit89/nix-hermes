# ---NIXMETA---
# domain:    70-forge
# id:        NIXH-70-FRG
# status:    active
# provides:
#   - my.services.forgejo.enable
#   - my.services.semaphore.enable
#   - my.services.cockpit.enable
# requires:
#   - 00-core
#   - 10-network
# adr:       ADR-70-forge.md
# guide:     70-forge.md
# complexity: 3
# reviewed:  2026-05-26
# ---ENDNIXMETA---

# ==============================================================================
# PURPOSE
# ==============================================================================
# Configures the forge ecosystem: Forgejo (git hosting), Semaphore (Ansible UI),
# and Cockpit (system administration).
# Key decisions -> ADR-70-forge.md

{ config, lib, pkgs, ... }:

let
  cfgForgejo = config.my.services.forgejo;
  cfgSemaphore = config.my.services.semaphore;
  cfgCockpit = config.my.services.cockpit;
  domain = config.my.configs.identity.domain;

in
{
  # ============================================================================
  # OPTIONS
  # ============================================================================
  options.my.services = {
    forgejo = {
      enable = lib.mkEnableOption "Forgejo self-hosted Git service";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.forgejo; description = "Forgejo HTTP port."; };
      disableRegistration = lib.mkOption { type = lib.types.bool; default = true; description = "Disable public user registration."; };
    };

    semaphore = {
      enable = lib.mkEnableOption "Semaphore Ansible Web UI";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.semaphore; description = "Semaphore HTTP port."; };
    };

    cockpit = {
      enable = lib.mkEnableOption "Cockpit Server Admin UI";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.cockpit; description = "Cockpit admin port."; };
      enableVirtualization = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Libvirtd KVM hypervisor and cockpit-machines management UI.";
      };
      exposeAmt = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose Intel AMT remote hardware management securely on machines.m7c5.de.";
      };
    };
  };

  # ============================================================================
  # CONFIG
  # ============================================================================
  config = lib.mkMerge [
    # ── FORGEJO GIT SERVICE ───────────────────────────────────────────────────
    (lib.mkIf cfgForgejo.enable {
      services.forgejo = {
        enable = true;
        database = {
          type = "postgres";
          createDatabase = true;
          user = "forgejo";
          name = "forgejo";
          socket = "/run/postgresql";
        };
        settings = {
          server = {
            HTTP_ADDR = "127.0.0.1";
            HTTP_PORT = cfgForgejo.port;
            ROOT_URL = "https://git.${domain}/";
          };
          service.DISABLE_REGISTRATION = cfgForgejo.disableRegistration;
        };
      };

      services.caddy.virtualHosts."git.${domain}" = {
        extraConfig = ''
          import security_headers
          reverse_proxy 127.0.0.1:${toString cfgForgejo.port}
        '';
      };
    })

    # ── SEMAPHORE ANSIBLE WEB UI ──────────────────────────────────────────────
    (lib.mkIf cfgSemaphore.enable {
      virtualisation.oci-containers = {
        backend = "podman";
        containers.semaphore = {
          image = "docker.io/semaphoreui/semaphore:latest";
          ports = [ "127.0.0.1:${toString cfgSemaphore.port}:3000" ];
          environment = {
            SEMAPHORE_DB_DIALECT = "sqlite";
            SEMAPHORE_PLAYBOOK_PATH = "/var/lib/semaphore/playbooks";
            SEMAPHORE_DB_PATH = "/var/lib/semaphore/semaphore.db";
          };
          volumes = [
            "/var/lib/semaphore:/var/lib/semaphore"
          ];
        };
      };

      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
      };

      services.caddy.virtualHosts."semaphore.${domain}" = {
        extraConfig = ''
          import sso_auth
          reverse_proxy 127.0.0.1:${toString cfgSemaphore.port}
        '';
      };
    })

    # ── COCKPIT SERVER ADMIN UI ───────────────────────────────────────────────
    (lib.mkIf cfgCockpit.enable {
      services = {
        cockpit = {
          enable = true;
          inherit (cfgCockpit) port;
        };

        caddy.virtualHosts = {
          "admin.${domain}" = {
            extraConfig = ''
              import sso_auth
              reverse_proxy 127.0.0.1:${toString cfgCockpit.port}
            '';
          };

          # ── SECURE INTEL AMT INGRESS (SSO POCKET-ID GATEKEEPER) ─────────────────
          "machines.${domain}" = lib.mkIf cfgCockpit.exposeAmt {
            extraConfig = ''
              import sso_auth
              reverse_proxy 192.168.1.100:16992
            '';
          };
        };
      };

      # ── KVM VIRTUALIZATION ENGINE (COCKPIT /MACHINES PATH) ──────────────────
      virtualisation.libvirtd = lib.mkIf cfgCockpit.enableVirtualization {
        enable = true;
        qemu = {
          package = pkgs.qemu_kvm;
          runAsRoot = true;
        };
      };

      environment.systemPackages = lib.mkIf cfgCockpit.enableVirtualization [
        pkgs.cockpit-machines # Exposes the native /machines tab inside Cockpit UI
      ];
    })
  ];
}
