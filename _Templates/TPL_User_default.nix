# @meta -------------------------------------------------
# type:       user-system-config
# status:     active
# ------------------------------------------------------
# PURPOSE: System-Ebene Definition für den Benutzer.
# Hier werden Rechte, UIDs, Gruppen und die Shell definiert.

{ config, pkgs, ... }:

{
  users.users."REPLACE_USER" = {
    isNormalUser = true;
    description = "REPLACE_USER";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.bash;
    
    # Best Practice: Passwort-Hash über SOPS einbinden
    # hashedPasswordFile = config.sops.secrets."users/REPLACE_USER/password".path;
  };
}
