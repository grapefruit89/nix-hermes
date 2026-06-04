# ---NIXMETA---
# domain:    50-media
# id:        NIXH-50-ARR
# status:    active
# provides:
#   - my.services.sonarr.enable
#   - my.services.radarr.enable
#   - my.services.readarr.enable
#   - my.services.prowlarr.enable
# requires:
#   - 00-core
#   - 10-network
#   - 20-security
#   - 50-media/arr-helper
# adr:       ADR-50-media.md
# guide:     50-media.md
# complexity: 3
# reviewed:  2026-06-03
# ---ENDNIXMETA---

{ config, lib, pkgs, ... }:

let
  cfgSonarr = config.my.services.sonarr;
  cfgRadarr = config.my.services.radarr;
  cfgReadarr = config.my.services.readarr;
  cfgProwlarr = config.my.services.prowlarr;

  ports = config.my.ports;
  arrHelper = import ./arr-helper.nix { inherit config lib pkgs; };

in
{
  config = lib.mkMerge [
    (lib.mkIf cfgSonarr.enable {
      sops.secrets.sonarr_api_key = { owner = "root"; };
    })
    (lib.mkIf cfgSonarr.enable (arrHelper.mkArrService {
      name = "sonarr";
      port = ports.sonarr;
      dataDir = "/var/lib/sonarr";
      uid = 989;
      gid = 989;
    }))

    (lib.mkIf cfgRadarr.enable {
      sops.secrets.radarr_api_key = { owner = "root"; };
    })
    (lib.mkIf cfgRadarr.enable (arrHelper.mkArrService {
      name = "radarr";
      port = ports.radarr;
      dataDir = "/var/lib/radarr";
      uid = 978;
      gid = 978;
    }))

    (lib.mkIf cfgReadarr.enable (arrHelper.mkArrService {
      name = "readarr";
      port = ports.readarr;
      dataDir = "/var/lib/readarr";
      uid = 987;
      gid = 987;
    }))

    (lib.mkIf cfgProwlarr.enable {
      sops.secrets.prowlarr_api_key = { owner = "root"; };
      sops.secrets.scenenzbs_api_key = { owner = "root"; };
    })
    (lib.mkIf cfgProwlarr.enable (arrHelper.mkArrService {
      name = "prowlarr";
      port = ports.prowlarr;
      dataDir = "/var/lib/prowlarr";
      uid = 969; # custom default UID for prowlarr
      gid = 969; # custom default GID for prowlarr
    }))
  ];
}
