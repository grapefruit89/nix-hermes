# ---NIXMETA---
# domain:    XX-name              # Must match modules/XX-name/ folder
# id:        NIXH-XX-SHORT        # XX = domain number, SHORT = 3-char module abbreviation
# status:    draft                # draft | active | deprecated
# provides:
#   - my.services.NAME.enable     # Every top-level option this module declares
# requires:
#   - 00-core                     # Domain-level deps (not file paths)
#   - 10-network                  # Add only what this module directly needs
# adr:       ADR-XX-name.md       # Single linked ADR (one module = one domain = one ADR)
# guide:     XX-name.md           # Single linked operational guide
# complexity: 2                   # 1 (trivial) to 5 (deep systemd/kernel interaction)
# reviewed:  YYYY-MM-DD
# ---ENDNIXMETA---

# ==============================================================================
# PURPOSE (one sentence, answers "what does this module do at runtime?")
# ==============================================================================
# Configures <service/subsystem> as the canonical <role> for this system.
# Key decisions → ADR-XX-name.md

{
  config,
  lib,
  pkgs,
  # myLib,    # uncomment if using shared lib-helpers
  ...
}: let
  # --------------------------------------------------------------------------
  # MODULE CONFIG REF
  # Alias to the module's own option namespace. Avoids repeating
  # config.my.services.NAME throughout the file.
  # --------------------------------------------------------------------------
  cfg = config.my.services.NAME;

  # --------------------------------------------------------------------------
  # LOCAL CONSTANTS
  # Pure values only — no config references here.
  # If a value depends on config.*, it belongs in the config block below.
  # --------------------------------------------------------------------------
  # someConstant = "value";

in {
  # ============================================================================
  # OPTIONS
  # Declare the public interface this module exposes.
  # Keep options minimal — prefer conventions over configuration.
  # ============================================================================
  options.my.services.NAME = {
    enable = lib.mkEnableOption "short description of what this enables";

    # Add further options only if they genuinely vary between hosts/profiles.
    # Do not add options just to document internal values.
  };

  # ============================================================================
  # CONFIG
  # The implementation. Guarded by lib.mkIf cfg.enable.
  # ============================================================================
  config = lib.mkIf cfg.enable {

    # --------------------------------------------------------------------------
    # SYSTEMD SERVICE (if applicable)
    # --------------------------------------------------------------------------
    systemd.services.NAME = {
      description = "Short description";
      wantedBy    = [ "multi-user.target" ];
      after       = [ "network.target" ]; # be explicit, not just network-online

      serviceConfig = {
        # --- IDENTITY ---
        User  = "NAME";
        Group = "NAME";

        # --- SANDBOXING (baseline — harden further per ADR-20-security) ---
        ProtectSystem         = "strict";
        ProtectHome           = true;
        PrivateTmp            = true;
        PrivateDevices        = true;
        NoNewPrivileges       = true;
        MemoryDenyWriteExecute = true;

        # --- STATE ---
        # Prefer StateDirectory/CacheDirectory over hardcoded paths.
        StateDirectory = "NAME";

        # --- RESTART ---
        Restart   = "on-failure";
        RestartSec = "5s";
      };
    };

    # --------------------------------------------------------------------------
    # USERS / GROUPS (if service runs under a dedicated user)
    # --------------------------------------------------------------------------
    users.users.NAME = {
      isSystemUser = true;
      group        = "NAME";
      # uid = config.my.users.registry.NAME;  # use central registry if present
    };
    users.groups.NAME = {};

    # --------------------------------------------------------------------------
    # PACKAGES (only what this module directly needs at runtime)
    # --------------------------------------------------------------------------
    # environment.systemPackages = [ pkgs.NAME ];

  };
}