# ---NIXMETA---
# domain:    60-apps
# id:        NIXH-60-HERMES
# status:    active
# provides:
#   - my.services.hermes.enable
# requires:
#   - 00-core
#   - 20-security
#   - 30-storage
# adr:       ADR-60-apps.md
# guide:     60-apps.md
# complexity: 3
# reviewed:  2026-06-04
# ---ENDNIXMETA---

{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.hermes;
in
{
  config = lib.mkIf cfg.enable {
    # 1. Enable standard Hermes Agent Service from the input flake module
    services.hermes-agent = {
      enable = true;
      settings = {
        model.default = "gemini-3-flash-preview";
        model.provider = "google-gemini-cli";
        context_compression = {
          threshold = 70;
          target_ratio = 0.30;
          protect_last = 15;
          protect_first = 2;
        };
      };
      addToSystemPackages = true;
      environmentFiles = [ "/var/lib/hermes/env" ];
    };

    # Allow WebUI port through the firewall
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    # 2. Hardened systemd service for Hermes WebUI
    systemd.services.hermes-webui = {
      description = "Hardened Hermes WebUI Service";
      after = [ "network.target" "hermes-agent.service" ];
      wants = [ "hermes-agent.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        HERMES_WEBUI_HOST = "0.0.0.0";
        HERMES_WEBUI_PORT = toString cfg.port;
        HERMES_WEBUI_PYTHON = "/root/hermes-webui/.venv/bin/python"; # Fallback virtualenv python
        HERMES_WEBUI_AGENT_DIR = "/root/.hermes";
        HOME = "/root";
        HERMES_WEBUI_SKIP_ONBOARDING = "1";
      };

      serviceConfig = {
        WorkingDirectory = "/root/hermes-webui";
        ExecStart = "/root/hermes-webui/.venv/bin/python /root/hermes-webui/server.py";
        Restart = "on-failure";
        RestartSec = "5s";
        User = "root";
        Group = "root";

        # systemd hardening measures
        ProtectSystem = "strict";
        ProtectHome = "read-only"; # WebUI must read /root/hermes-webui but cannot write to /root
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        ReadWritePaths = [ "/var/lib/hermes" "/root/.hermes" ];
      };
    };
  };
}
