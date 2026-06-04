# @meta -------------------------------------------------
# type:       user-system-config
# status:     active
# ------------------------------------------------------
# PURPOSE: System-Ebene Definition für den Benutzer.
# Hier werden Rechte, UIDs, Gruppen und die Shell definiert.

{ config, pkgs, ... }:

{
  imports = [
    ./preferences.nix
  ];

  users.users."moritz" = {
    isNormalUser = true;
    description = "moritz";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx moritz@client"
    ];

    # Best Practice: Passwort-Hash über SOPS einbinden
    # hashedPasswordFile = config.sops.secrets."users/moritz/password".path;
  };
}

