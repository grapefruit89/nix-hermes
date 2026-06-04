{
  description = "NixOS Configuration — Q958 Server + Laptop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, impermanence, home-manager, sops-nix, ... }: {
    nixosConfigurations = {
      q958 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          ./hosts/q958/configuration.nix
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
        ];
      };

      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          ./hosts/laptop/configuration.nix
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops
        ];
      };
    };
  };
}
