# @meta -------------------------------------------------
# type:       user-system-config
# status:     active
# ------------------------------------------------------
# PURPOSE: System-Ebene Definition für den Benutzer.
# Hier werden Rechte, UIDs, Gruppen und die Shell definiert.

{ config, pkgs, ... }:

{
  users.users."freund" = {
    isNormalUser = true;
    description = "freund";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.bash;

    # Best Practice: Passwort-Hash über SOPS einbinden
    # hashedPasswordFile = config.sops.secrets."users/freund/password".path;
  };
}

