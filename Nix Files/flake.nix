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

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, impermanence, home-manager, hermes-agent, nixos-wsl, ... }: {
    nixosConfigurations = {
      q958 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          ./hosts/q958/configuration.nix
          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          hermes-agent.nixosModules.default
        ];
      };

      laptop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          ./hosts/laptop/configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };

      wsl = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit self; };
        modules = [
          ./hosts/wsl/configuration.nix
          nixos-wsl.nixosModules.default
          home-manager.nixosModules.home-manager
          hermes-agent.nixosModules.default
        ];
      };
    };
  };
}
