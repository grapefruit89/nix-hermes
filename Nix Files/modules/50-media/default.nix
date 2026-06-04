# ---NIXMETA---
# domain:    50-media
# id:        NIXH-50-MED
# status:    active
# provides:
#   - my.services.jellyfin.enable
#   - my.services.jellyseerr.enable
#   - my.services.sonarr.enable
#   - my.services.radarr.enable
#   - my.services.readarr.enable
#   - my.services.prowlarr.enable
#   - my.services.sabnzbd.enable
# requires:
#   - 00-core
#   - 10-network
# adr:       ADR-50-media.md
# guide:     50-media.md
# complexity: 3
# reviewed:  2026-06-03
# ---ENDNIXMETA---

{ config, lib, pkgs, ... }:

{
  imports = [
    ./jellyfin.nix
    ./arr-stack.nix
    ./sabnzbd.nix
    ./sync.nix
  ];

  # Centralized options declaration for domain 50
  options.my.services = {
    jellyfin.enable = lib.mkEnableOption "Jellyfin Media Server with Intel QuickSync";
    jellyseerr.enable = lib.mkEnableOption "Jellyseerr Request Manager";
    sonarr.enable = lib.mkEnableOption "Sonarr Series Manager";
    radarr.enable = lib.mkEnableOption "Radarr Movies Manager";
    readarr.enable = lib.mkEnableOption "Readarr Books Manager";
    prowlarr.enable = lib.mkEnableOption "Prowlarr Indexer Proxy";
    sabnzbd.enable = lib.mkEnableOption "SABnzbd Usenet Downloader";
  };
}
