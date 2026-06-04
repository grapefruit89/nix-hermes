# ---NIXMETA---
# domain:    50-media
# id:        NIXH-50-SAB
# status:    active
# provides:
#   - my.services.sabnzbd.enable
# requires:
#   - 00-core
#   - 10-network
#   - 20-security
# adr:       ADR-50-media.md
# guide:     50-media.md
# complexity: 3
# reviewed:  2026-06-03
# ---ENDNIXMETA---

{ config, lib, pkgs, ... }:

let
  cfgSabnzbd = config.my.services.sabnzbd;
  domain = config.my.configs.identity.domain;
  portSabnzbd = config.my.ports.sabnzbd;

in
{
  config = lib.mkIf cfgSabnzbd.enable {
    sops.secrets.sabnzbd_api_key = { owner = "root"; };
    sops.secrets.sabnzbd_usenet_user = { owner = "root"; };
    sops.secrets.sabnzbd_usenet_password = { owner = "root"; };

    services.sabnzbd = {
      enable = true;
      openFirewall = false;
      configFile = "/var/lib/sabnzbd/sabnzbd.ini";
    };

    # GID/UID und Gruppen-Anpassung
    users.groups.media = { };
    users.groups.sabnzbd.gid = lib.mkDefault 194;
    users.users.sabnzbd = {
      uid = lib.mkDefault 984;
      extraGroups = [ "media" ];
    };

    systemd.services.sabnzbd = {
      bindsTo = lib.optional config.my.services.privado-vpn.enable "sys-subsystem-net-devices-privado.device";
      after = lib.optional config.my.services.privado-vpn.enable "sys-subsystem-net-devices-privado.device";

      serviceConfig = {
        ProtectSystem = lib.mkForce "strict";
        ProtectHome = lib.mkForce true;
        PrivateTmp = lib.mkForce true;
        PrivateDevices = lib.mkForce true;
        NoNewPrivileges = lib.mkForce true;
        UMask = "0002"; # Prevents permission drift on downloaded files
        RestrictNetworkInterfaces = lib.optionals config.my.services.privado-vpn.enable [ "lo" "privado" ];

        # RAM-backed temporary download directory (SSD Longevity & Speed boost)
        RuntimeDirectory = "sabnzbd-tmp";
        RuntimeDirectoryMode = "0700";

        ReadWritePaths = [
          "/var/lib/sabnzbd"
          "/data/downloads"
          "/run/sabnzbd-tmp"
        ];
      };
    };

    services.caddy.virtualHosts."sabnzbd.${domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString portSabnzbd}
      '';
    };
  };
}
