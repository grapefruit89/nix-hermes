# ---NIXMETA---
# domain:    30-storage
# id:        NIXH-35-AUT
# status:    active
# provides:
#   - my.services.storage-automount.enable
# requires:
#   - 30-storage
# adr:       ADR-30-storage.md
# guide:     30-storage.md
# complexity: 4
# reviewed:  2026-06-02
# ---ENDNIXMETA---

# 35-automount.nix – Enhanced Auto-Tiering mit Label-basierter Klassifikation
{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.storage-automount;
  mediaGroup = "media";
in
{
  options.my.services.storage-automount = {
    enable = lib.mkEnableOption "Automated storage auto-mounting and pooling with Tier A/B/C";

    # Fallback-Konfiguration für Laufwerke ohne Label
    defaultTierForInternalSSD = lib.mkOption {
      type = lib.types.enum [ "A" "B" "C" ];
      default = "B";
      description = "Tier für interne SSDs ohne erkennbares Label";
    };

    defaultTierForInternalHDD = lib.mkOption {
      type = lib.types.enum [ "A" "B" "C" ];
      default = "C";
      description = "Tier für interne HDDs ohne erkennbares Label";
    };
  };

  config = lib.mkIf cfg.enable {
    # Udev-Regeln: Auf alle Partitionen mit Dateisystem reagieren
    services.udev.extraRules = ''
      # Trigger für Partitionen mit einem erkannten Dateisystem (intern und extern)
      SUBSYSTEM=="block", ACTION=="add", ENV{DEVTYPE}=="partition", ENV{ID_FS_TYPE}=="?*", TAG+="systemd", ENV{SYSTEMD_WANTS}+="nixhome-automount@%k.service"
      SUBSYSTEM=="block", ACTION=="remove", ENV{DEVTYPE}=="partition", RUN+="${pkgs.systemd}/bin/systemctl stop nixhome-automount@%k.service"
    '';

    systemd.services."nixhome-automount@" = {
      description = "NixHome Tiered Automounter for device %I";
      path = with pkgs; [ util-linux udev gnugrep coreutils systemd procps psmisc ];

      bindsTo = [ "dev-%i.device" ];
      after = [ "dev-%i.device" "local-fs.target" ];
      requires = [ "dev-%i.device" ];
      partOf = [ "dev-%i.device" ];

      unitConfig = {
        StopWhenUnneeded = true;
        CollectMode = "inactive-or-failed";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        # Sandboxing & Hardening
        CapabilityBoundingSet = [ "CAP_SYS_ADMIN" "CAP_CHOWN" "CAP_FOWNER" "CAP_DAC_OVERRIDE" ];
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateNetwork = true;
        ReadWritePaths = [ "/mnt" ];

        ExecStart = pkgs.writeShellScript "tiered-automount" ''
          DEV="/dev/%I"
          if [ ! -b "$DEV" ]; then
            echo "Device $DEV is not a valid block device. Exiting."
            exit 0
          fi

          # ---- Laufwerksinformationen sammeln ----
          LABEL=$(blkid -o value -s LABEL "$DEV" | sed 's/[^a-zA-Z0-9_-]/_/g' || true)
          UUID=$(blkid -o value -s UUID "$DEV" || true)
          if [ -z "$UUID" ]; then
            echo "No UUID found for $DEV. Cannot mount safely. Exiting."
            exit 0
          fi
          [ -n "$LABEL" ] || LABEL="disk-$UUID"

          BUS=$(udevadm info --query=property --name="$DEV" | grep "ID_BUS=" | cut -d= -f2 || true)
          
          DISK_NAME=$(echo "%I" | sed 's/[0-9]*//g')
          ROTATIONAL="1"
          if [ -f "/sys/block/$DISK_NAME/queue/rotational" ]; then
            ROTATIONAL=$(cat "/sys/block/$DISK_NAME/queue/rotational")
          fi
          
          SIZE_SECTORS="0"
          if [ -f "/sys/block/$DISK_NAME/size" ]; then
            SIZE_SECTORS=$(cat "/sys/block/$DISK_NAME/size")
          fi
          SIZE_GB=$((SIZE_SECTORS * 512 / 1000000000))

          # ---- Klassifikation ----
          # 1. Externe Geräte (USB)
          if [ "$BUS" = "usb" ]; then
            # Explizites Label für externe Typen
            if [[ "$LABEL" =~ ^EXT_SSD_ ]]; then
              TIER="EXT_SSD"
              MOUNT_BASE="/mnt/external/ssd"
            elif [[ "$LABEL" =~ ^EXT_HDD_ ]]; then
              TIER="EXT_HDD"
              MOUNT_BASE="/mnt/external/hdd"
            elif [[ "$LABEL" =~ ^EXT_USB_ ]]; then
              TIER="EXT_USB"
              MOUNT_BASE="/mnt/external/usb"
            else
              # Automatische Erkennung
              if [ "$ROTATIONAL" = "0" ]; then
                if [ "$SIZE_GB" -gt 128 ]; then
                  TIER="EXT_SSD"
                  MOUNT_BASE="/mnt/external/ssd"
                else
                  TIER="EXT_USB"
                  MOUNT_BASE="/mnt/external/usb"
                fi
              else
                TIER="EXT_HDD"
                MOUNT_BASE="/mnt/external/hdd"
              fi
            fi
            MOUNT_DIR="$MOUNT_BASE-$LABEL"
            USE_POOL="external_pool"
          
          # 2. Interne Geräte (SATA/NVMe) – Label-basierte Tier-Zuordnung
          else
            # Priorität 1: Explizites Label-Präfix
            if [[ "$LABEL" =~ ^TIER_A_ ]]; then
              TIER="INT_A"
              MOUNT_DIR="/mnt/tier-a/$LABEL"
              USE_POOL="none"
            elif [[ "$LABEL" =~ ^TIER_B_ ]]; then
              TIER="INT_B"
              MOUNT_DIR="/mnt/tier-b/$LABEL"
              USE_POOL="fast_pool"
            elif [[ "$LABEL" =~ ^TIER_C_ ]] || [[ "$LABEL" =~ ^DISK_STORAGE_ ]]; then
              TIER="INT_C"
              MOUNT_DIR="/mnt/tier-c/$LABEL"
              USE_POOL="media_pool"
            else
              # Fallback: Automatische Zuordnung ohne Label
              if [ "$ROTATIONAL" = "0" ]; then
                # Interne SSD ohne Label → Verwende defaultTierForInternalSSD
                case "${cfg.defaultTierForInternalSSD}" in
                  "A") TIER="INT_A"; MOUNT_DIR="/mnt/tier-a/auto-$LABEL"; USE_POOL="none" ;;
                  "B") TIER="INT_B"; MOUNT_DIR="/mnt/tier-b/auto-$LABEL"; USE_POOL="fast_pool" ;;
                  "C") TIER="INT_C"; MOUNT_DIR="/mnt/tier-c/auto-$LABEL"; USE_POOL="media_pool" ;;
                esac
              else
                # Interne HDD ohne Label → defaultTierForInternalHDD
                case "${cfg.defaultTierForInternalHDD}" in
                  "A") TIER="INT_A"; MOUNT_DIR="/mnt/tier-a/auto-$LABEL"; USE_POOL="none" ;;
                  "B") TIER="INT_B"; MOUNT_DIR="/mnt/tier-b/auto-$LABEL"; USE_POOL="fast_pool" ;;
                  "C") TIER="INT_C"; MOUNT_DIR="/mnt/tier-c/auto-$LABEL"; USE_POOL="media_pool" ;;
                esac
              fi
            fi
          fi

          # Prevent double mount races
          if mountpoint -q "$MOUNT_DIR"; then
            echo "Mountpoint $MOUNT_DIR is already mounted. Skipping."
            exit 0
          fi

          echo "Mounting $DEV as $TIER → $MOUNT_DIR"
          mkdir -p "$MOUNT_DIR"
          
          # ---- Dateisystemabhängiges Mounten ----
          FSTYPE=$(blkid -o value -s TYPE "$DEV" || true)
          case "$FSTYPE" in
            btrfs)   mount -o noatime,compress=zstd,nofail "$DEV" "$MOUNT_DIR" ;;
            ext4)    mount -o noatime,nofail "$DEV" "$MOUNT_DIR" ;;
            ntfs|exfat|vfat)
                     mount -o noatime,utf8,nofail "$DEV" "$MOUNT_DIR" || \
                     mount -o noatime,nofail "$DEV" "$MOUNT_DIR" ;;
            *)       echo "Unsupported FS: $FSTYPE. Trying raw mount..."; mount -o noatime,nofail "$DEV" "$MOUNT_DIR" ;;
          esac
          
          # ---- Berechtigungen (Gruppe media) ----
          chown -R root:${mediaGroup} "$MOUNT_DIR" 2>/dev/null || true
          chmod -R 775 "$MOUNT_DIR" 2>/dev/null || true
          find "$MOUNT_DIR" -type d -exec chmod g+s {} + 2>/dev/null || true
          
          # ---- MergerFS-Pools benachrichtigen (SIGHUP) ----
          if [ "$USE_POOL" != "none" ]; then
            echo "Signalling MergerFS to refresh pool: $USE_POOL"
            killall -SIGHUP mergerfs || true
          fi
        '';

        ExecStop = pkgs.writeShellScript "tiered-autounmount" ''
          DEV="/dev/%I"
          MNT_PATHS=$(mount | grep "^$DEV " | cut -d' ' -f3 || true)
          for p in $MNT_PATHS; do
            echo "Unmounting path: $p..."
            umount -l "$p" 2>/dev/null && rmdir "$p" 2>/dev/null
          done
          killall -SIGHUP mergerfs || true
        '';
      };
    };
  };
}
