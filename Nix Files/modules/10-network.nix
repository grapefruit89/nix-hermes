# ---NIXMETA---
# domain:    10-network
# id:        NIXH-10-NET
# status:    active
# provides:
#   - my.services.adguardhome.enable
#   - my.services.valkey.enable
#   - my.services.postgresql.enable
# requires:
#   - 00-core
# adr:       ADR-10-network.md
# guide:     10-network.md
# complexity: 3
# reviewed:  2026-05-26
# ---ENDNIXMETA---

# ==============================================================================
# PURPOSE
# ==============================================================================
# Configures local networking infrastructure and central database plumbing, 
# including AdGuard Home, Valkey (Redis-fork) cache, and the PostgreSQL server.
# Key decisions -> ADR-10-network.md

{ config, lib, pkgs, ... }:

let
  cfgAdguard = config.my.services.adguardhome;
  cfgValkey = config.my.services.valkey;
  cfgPostgres = config.my.services.postgresql;

  lanIP = config.my.configs.server.lanIP;
  tailscaleIP = config.my.configs.server.tailscaleIP;
  dnsDoH = config.my.configs.network.dnsDoH;
  dnsBootstrap = config.my.configs.network.dnsBootstrap;
  domain = config.my.configs.identity.domain;
  portAdguard = config.my.ports.adguard;
  portValkey = config.my.ports.valkey;

in
{
  # ============================================================================
  # OPTIONS
  # ============================================================================
  options.my.services = {
    adguardhome.enable = lib.mkEnableOption "AdGuardHome DNS Filter and Resolver";
    valkey.enable = lib.mkEnableOption "Valkey cache server (Redis-fork)";
    postgresql.enable = lib.mkEnableOption "PostgreSQL database server";

    # 🛑 Blocky DNS Resolver
    blocky = {
      enable = lib.mkEnableOption "Blocky DNS Resolver";
      port = lib.mkOption { type = lib.types.port; default = 53; description = "Blocky DNS listening port."; };
      metricsPort = lib.mkOption { type = lib.types.port; default = 4000; description = "Blocky HTTP metrics port."; };
      upstreamDns = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ "1.1.1.1" "8.8.8.8" ]; description = "List of upstream DNS servers."; };
    };

    # 🔗 Tailscale VPN
    tailscale = {
      enable = lib.mkEnableOption "Tailscale Zero-Trust VPN";
      port = lib.mkOption { type = lib.types.port; default = 41641; description = "Tailscale UDP WireGuard port."; };
    };

    # 🛡️ Privado VPN WireGuard Client
    privado-vpn = {
      enable = lib.mkEnableOption "Privado VPN WireGuard Client Tunnel";
      ipAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.0.0.2/32";
        description = "Privado VPN interface IP address.";
      };
      dns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "10.255.255.255" ];
        description = "DNS servers to bind to the VPN interface.";
      };
      publicKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Privado VPN server WireGuard public key.";
      };
      endpoint = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Privado VPN server endpoint IP and port.";
      };
    };

    # 🔑 PocketID Identity Provider
    pocket-id = {
      enable = lib.mkEnableOption "PocketID OIDC Passkey Provider";
      port = lib.mkOption { type = lib.types.port; default = config.my.ports.pocket-id; description = "PocketID web interface listening port."; };
      dataDir = lib.mkOption { type = lib.types.str; default = "/var/lib/pocket-id"; description = "Database state directory."; };
    };
  };

  # ============================================================================
  # CONFIG
  # ============================================================================
  config = lib.mkMerge [
    # ── ADGUARD HOME ──────────────────────────────────────────────────────────
    (lib.mkIf cfgAdguard.enable {
      services.adguardhome = {
        enable = true;
        host = "127.0.0.1";
        port = portAdguard;
        openFirewall = false;

        settings = {
          http.address = "127.0.0.1:${toString portAdguard}";

          dns = {
            bind_hosts = [ "127.0.0.1" lanIP tailscaleIP ];
            port = 53;
            upstream_dns = dnsDoH;
            bootstrap_dns = dnsBootstrap;
            fallback_dns = config.my.configs.network.dnsFallback;
            cache_size = 33554432; # 32MB Cache
            cache_ttl_min = 300;
            cache_ttl_max = 86400; # Max TTL 24h
            cache_optimistic = true;
            filtering_enabled = true;
            filters_update_interval = 24;
            edns_cs_enabled = false;
            dnssec_enabled = true;
            all_servers = false;
            fastest_addr = true;
          };

          querylog = {
            enabled = true;
            file_enabled = true;
            interval = "24h";
            size_memory = 1000;
            add_timestamps = true;
          };

          statistics = {
            enabled = true;
            interval = "168h"; # 7 Tage
          };

          filtering = {
            protection_enabled = true;
            filtering_enabled = true;
            safe_browsing = { enabled = true; };
            parental = { enabled = false; };
            safe_search = { enabled = false; };
          };

          rewrites = [
            { domain = "nixhome.local"; answer = lanIP; }
            { domain = "*.${domain}"; answer = lanIP; }
            { domain = "*.nix.${domain}"; answer = lanIP; }
            { domain = "auth.${domain}"; answer = lanIP; }
            { domain = "netdata.${domain}"; answer = lanIP; }
          ];

          clients.persistent = [
            { ids = [ lanIP ]; name = "nixhome-server"; }
          ];

          user_rules = [
            "@@||nixhome.local^"
            "@@||${domain}^"
          ];
        };
      };

      services.caddy.virtualHosts."dns.${domain}" = {
        extraConfig = ''
          import sso_auth
          reverse_proxy 127.0.0.1:${toString portAdguard}
        '';
      };

      systemd.services.AdGuardHome.serviceConfig = {
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        NoNewPrivileges = true;
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" "CAP_NET_RAW" ];
        ReadWritePaths = [ "/var/lib/AdGuardHome" ];
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallFilter = [ "@system-service" ];
        OOMScoreAdjust = -200;
      };
    })

    # ── VALKEY CACHE DATABASE (Valkey package inside Redis module) ────────────
    (lib.mkIf cfgValkey.enable {
      services.redis = {
        package = pkgs.valkey;
        servers.valkey = {
          enable = true;
          bind = "127.0.0.1"; # Lokal isolierter Ingress
          port = portValkey;
          openFirewall = false;
          unixSocket = "/run/redis-valkey/valkey.sock";
          unixSocketPerm = 660;
          settings = {
            maxmemory = "256mb";
            maxmemory-policy = "allkeys-lru";
            save = [ "900 1" "300 10" ];
          };
        };
      };

      # Valkey Server Sandboxing
      systemd.services.redis-valkey.serviceConfig = {
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        MemoryDenyWriteExecute = true;
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        ReadWritePaths = [ "/var/lib/redis-valkey" ];
      };
    })

    # ── POSTGRESQL DATABASE SERVER ────────────────────────────────────────────
    (lib.mkIf cfgPostgres.enable {
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_16;

        # Rationale: Liegt auf Fast-Tier SSD/NVMe (Ext4/Btrfs mit noatime), getrennt von mergerfs
        dataDir = "/var/lib/postgresql";

        # Unix Sockets bevorzugen, TCP/IP standardmäßig deaktiviert (Zero-Trust)
        enableTCPIP = false;

        # Streng lokaler Socket-Zugriff per Ident-Validation
        authentication = pkgs.lib.mkForce ''
          # TYPE  DATABASE        USER            ADDRESS                 METHOD
          local   all             all                                     ident
        '';

        settings = {
          # Rationale: Erzwingt UTF-8 Locales für reibungslosen Start aller migrierten Apps (verknüpft mit Zentral-Locale)
          lc_messages = config.my.configs.locale.default;
          lc_monetary = config.my.configs.locale.default;
          lc_numeric = config.my.configs.locale.default;
          lc_time = config.my.configs.locale.default;

          # Performance-Tuning für 16GB Homelab Hardware (Fujitsu Q958)
          shared_buffers = "4GB";
          work_mem = "64MB";
          maintenance_work_mem = "512MB";
          effective_cache_size = "12GB";
          max_connections = 100;
        };
      };

      # PostgreSQL Systemd Sandboxing Härtung
      systemd.services.postgresql.serviceConfig = {
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        ReadWritePaths = [ "/var/lib/postgresql" ];
      };
    })

    # ── BLOCKY DNS RESOLVER ───────────────────────────────────────────────────
    (lib.mkIf config.my.services.blocky.enable {
      services.blocky = {
        enable = true;
        settings = {
          ports = {
            dns = config.my.services.blocky.port;
            http = config.my.services.blocky.metricsPort;
          };
          upstreams.groups.default = config.my.services.blocky.upstreamDns;
        };
      };
    })

    # ── TAILSCALE VPN ─────────────────────────────────────────────────────────
    (lib.mkIf config.my.services.tailscale.enable {
      sops.secrets.tailscale_token = { owner = "root"; };

      services.tailscale = {
        enable = true;
        openFirewall = true;
        port = config.my.services.tailscale.port;
        permitCertUid = "caddy";
        useRoutingFeatures = "client";
        extraUpFlags = [ "--ssh" "--accept-dns=true" "--accept-routes=true" ];
      };
      networking.firewall.trustedInterfaces = [ "tailscale0" ];
      networking.firewall.checkReversePath = "loose";

      systemd.services.tailscale-autoconnect = {
        description = "Automatic Tailscale Login";
        after = [ "tailscaled.service" "network-online.target" ];
        wants = [ "tailscaled.service" "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "tailscale-auth" ''
            sleep 2
            status=$(${pkgs.tailscale}/bin/tailscale status --json | ${pkgs.jq}/bin/jq -r .BackendState)
            if [ "$status" = "NeedsLogin" ] || [ "$status" = "Stopped" ]; then
              ${pkgs.tailscale}/bin/tailscale up --authkey="$(cat /run/secrets/tailscale_token)"
            fi
          '';
        };
      };

      systemd.services.tailscaled = {
        stopIfChanged = false;
        serviceConfig = {
          Restart = "always";
          RestartSec = "2s";
          OOMScoreAdjust = -1000;
          ProtectSystem = "strict";
          ProtectHome = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        };
      };
    })

    # ── PRIVADO VPN WIREGUARD CLIENT ──────────────────────────────────────────
    (lib.mkIf config.my.services.privado-vpn.enable {
      sops.secrets.privado_private_key = { owner = "root"; };

      networking.wg-quick.interfaces.privado = {
        autostart = true;
        address = [ config.my.services.privado-vpn.ipAddress ];
        dns = config.my.services.privado-vpn.dns;
        privateKeyFile = config.sops.secrets.privado_private_key.path;

        peers = [{
          publicKey = config.my.services.privado-vpn.publicKey;
          endpoint = config.my.services.privado-vpn.endpoint;
          allowedIPs = [ "0.0.0.0/0" ];
        }];
      };

      systemd.services.wg-quick-privado = {
        serviceConfig = {
          Restart = "always";
          RestartSec = "5s";
        };
      };
    })

    # ── POCKETID IDENTITY PROVIDER ────────────────────────────────────────────
    (lib.mkIf config.my.services.pocket-id.enable {
      services.pocket-id = {
        enable = true;
        dataDir = config.my.services.pocket-id.dataDir;
        settings = {
          PORT = toString config.my.services.pocket-id.port;
          PUBLIC_URL = "https://auth.${domain}";
          RP_ID = "auth.${domain}";
          RP_NAME = "PocketID";
          SESSION_DURATION = "24h";
          ATTESTATION = "direct";
          USER_VERIFICATION = "preferred";
          PUBLIC_REGISTRATION = "false";
          TRUST_PROXY = true;
        };
      };

      systemd.services.pocket-id.serviceConfig = {
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ReadWritePaths = [ config.my.services.pocket-id.dataDir ];
        OOMScoreAdjust = -900;
      };

      services.caddy.virtualHosts."auth.${domain}" = {
        extraConfig = ''
          import security_headers
          reverse_proxy 127.0.0.1:${toString config.my.services.pocket-id.port}
        '';
      };
    })

    # ── CADDY GLOBAL CONFIG & SNIPPETS ────────────────────────────────────────
    {
      services.caddy = {
        extraConfig = lib.mkBefore ''
          (security_headers) {
            header {
              Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
              X-XSS-Protection "1; mode=block"
              X-Content-Type-Options "nosniff"
              X-Frame-Options "DENY"
              Referrer-Policy "strict-origin-when-cross-origin"
              Content-Security-Policy "upgrade-insecure-requests"
            }
          }

          (sso_auth) {
            forward_auth 127.0.0.1:${toString config.my.ports.pocket-id} {
              uri /api/auth/verify
              copy_headers X-Forwarded-User
            }
          }
        '';
      };
    }
  ];
}
