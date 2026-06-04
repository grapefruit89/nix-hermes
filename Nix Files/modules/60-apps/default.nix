# ---NIXMETA---
# domain:    60-apps
# id:        NIXH-60-APP
# status:    active
# provides:
#   - my.services.vaultwarden.enable
#   - my.services.homepage.enable
#   - my.services.home-assistant.enable
#   - my.services.zigbee-stack.enable
#   - my.services.paperless.enable
#   - my.services.n8n.enable
#   - my.services.filebrowser.enable
#   - my.services.linkwarden.enable
#   - my.services.open-webui.enable
# requires:
#   - 00-core
#   - 10-network
#   - 20-security
# adr:       ADR-60-apps.md
# guide:     60-apps.md
# complexity: 3
# reviewed:  2026-06-03
# ---ENDNIXMETA---

{ config, lib, pkgs, ... }:

let
  cfgVaultwarden = config.my.services.vaultwarden;
  cfgHomepage = config.my.services.homepage;
  cfgHass = config.my.services.home-assistant;
  cfgZigbee = config.my.services.zigbee-stack;
  cfgPaperless = config.my.services.paperless;
  cfgN8n = config.my.services.n8n;
  cfgFilebrowser = config.my.services.filebrowser;
  cfgLinkwarden = config.my.services.linkwarden;
  cfgOpenWebui = config.my.services.open-webui;

  anyEnabled =
    cfgVaultwarden.enable ||
    cfgHomepage.enable ||
    cfgHass.enable ||
    cfgZigbee.enable ||
    cfgPaperless.enable ||
    cfgN8n.enable ||
    cfgFilebrowser.enable ||
    cfgLinkwarden.enable ||
    cfgOpenWebui.enable;

in
{
  imports = [
    ./core.nix
    ./iot.nix
    ./automation.nix
  ];

  # Centralized options declaration for domain 60
  options.my.services = {
    vaultwarden.enable = lib.mkEnableOption "Vaultwarden Password Manager";
    homepage.enable = lib.mkEnableOption "Homepage Dashboard";

    # 🏠 Home Assistant (IoT)
    home-assistant = {
      enable = lib.mkEnableOption "Home Assistant (IoT)";
      user = lib.mkOption { type = lib.types.str; default = "hass"; description = "Home Assistant system user."; };
      group = lib.mkOption { type = lib.types.str; default = "hass"; description = "Home Assistant system group."; };
      port = lib.mkOption { type = lib.types.port; default = 8123; description = "Home Assistant port."; };
      stateDir = lib.mkOption { type = lib.types.str; default = "/var/lib/hass"; description = "State directory (Tier A)."; };
      cacheDir = lib.mkOption { type = lib.types.str; default = "/var/cache/home-assistant"; description = "Python cache directory (Tier B)."; };
      mediaDir = lib.mkOption { type = lib.types.str; default = "/var/lib/home-assistant/media"; description = "Media directory (Tier C)."; };
      zigbeeDevice = lib.mkOption { type = lib.types.str; default = "socket://192.168.1.100:6638"; description = "SLZB-06 socket or serial port path."; };
      bluetooth = lib.mkOption { type = lib.types.bool; default = false; description = "Enable bluetooth device access."; };
      secretFile = lib.mkOption { type = lib.types.nullOr lib.types.path; default = null; description = "Path to SOPS secrets file."; };
      extraComponents = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; description = "Extra components to load."; };
      trustedProxies = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ "127.0.0.1" "::1" ]; description = "List of trusted upstream proxies."; };
    };

    # 🐝 Zigbee Stack (Mosquitto + Zigbee2MQTT)
    zigbee-stack = {
      enable = lib.mkEnableOption "Zigbee Stack (Mosquitto + Zigbee2MQTT)";
      mqttPort = lib.mkOption { type = lib.types.port; default = 1883; description = "Local Mosquitto port."; };
      zigbeePort = lib.mkOption { type = lib.types.port; default = 8075; description = "Zigbee2MQTT port."; };
      zigbeeDevice = lib.mkOption { type = lib.types.str; default = "socket://192.168.1.100:6638"; description = "SLZB-06 socket or serial port path."; };
      adapter = lib.mkOption { type = lib.types.enum [ "ember" "zstack" "deconz" "ezsp" ]; default = "ember"; description = "Ember adapter type."; };
      dataDir = lib.mkOption { type = lib.types.str; default = "/var/lib/zigbee2mqtt"; description = "Zigbee2MQTT data folder."; };
    };

    # 📄 Paperless-ngx Document Archive
    paperless = {
      enable = lib.mkEnableOption "Paperless-ngx Document Archive";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.paperless; description = "Paperless-ngx web port."; };
      dataDir = lib.mkOption { type = lib.types.str; default = "/var/lib/paperless"; description = "Data directory."; };
      consumptionDir = lib.mkOption { type = lib.types.str; default = "/var/lib/paperless/consume"; description = "Consumption directory."; };
    };

    # 🔄 n8n Workflow Automation
    n8n = {
      enable = lib.mkEnableOption "n8n Workflow Automation Platform";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.n8n; description = "n8n port."; };
      userFolder = lib.mkOption { type = lib.types.str; default = "/var/lib/n8n"; description = "n8n state directory."; };
    };

    # 📂 Filebrowser Web Manager
    filebrowser = {
      enable = lib.mkEnableOption "Filebrowser Web File Manager";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.filebrowser; description = "Filebrowser port."; };
      rootPath = lib.mkOption { type = lib.types.str; default = "/mnt/documents"; description = "Root directory to serve."; };
      databasePath = lib.mkOption { type = lib.types.str; default = "/data/state/filebrowser/filebrowser.db"; description = "Database file path."; };
    };

    # 🔗 Linkwarden Bookmarks
    linkwarden = {
      enable = lib.mkEnableOption "Linkwarden Collaborative Bookmark Manager";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.linkwarden; description = "Linkwarden port."; };
    };

    # 🧠 Open WebUI LLM Interface
    open-webui = {
      enable = lib.mkEnableOption "Open WebUI for LLM interaction";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.open-webui; description = "Open WebUI port."; };
      ollamaUrl = lib.mkOption { type = lib.types.str; default = "http://127.0.0.1:11434"; description = "Ollama endpoint URL."; };
    };
  };

  config = lib.mkIf anyEnabled {
    services.caddy = {
      enable = true;
    };

    systemd.services.caddy.serviceConfig = {
      OOMScoreAdjust = lib.mkForce (-900);
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce "5s";
    };
  };
}
