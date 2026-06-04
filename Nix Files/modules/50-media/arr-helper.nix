# ---NIXMETA---
# domain:    50-media
# id:        NIXH-50-HELP
# status:    active
# provides:  []
# requires:  []
# adr:       ADR-50-media.md
# guide:     50-media.md
# ---ENDNIXMETA---

# arr-helper.nix
# Shared helper to generate standardized *Arr services.
{ config, lib, pkgs, ... }:

{
  mkArrService = { name, port, dataDir, uid, gid }: {
    services.${name} = {
      enable = true;
      openFirewall = false;
      dataDir = dataDir;
    };

    users.groups.${name} = {
      gid = lib.mkDefault gid;
    };
    users.users.${name} = {
      uid = lib.mkDefault uid;
      group = name;
      isSystemUser = true;
      extraGroups = [ "media" ];
    };

    systemd.services.${name}.serviceConfig = {
      ProtectSystem = lib.mkForce "strict";
      ProtectHome = lib.mkForce true;
      PrivateTmp = lib.mkForce true;
      PrivateDevices = lib.mkForce true;
      NoNewPrivileges = lib.mkForce true;
      UMask = lib.mkForce "0002";
      ReadWritePaths = [
        dataDir
        "/data/media"
        "/data/downloads"
      ];
    };

    services.caddy.virtualHosts."${name}.${config.my.configs.identity.domain}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString port}
      '';
    };
  };
}
