{
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = { nixpkgs, home-manager, hardware, ... }@inputs: {
    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    # (defaults to system hostname if not specified, and if
    # /etc/nixos/flake.nix exists then that will be used without
    # needing the "--flake" option).
    nixosConfigurations = {
      # Framework Laptop
      fwnixos = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          # A collection of NixOS modules covering hardware quirks.
          # https://github.com/NixOS/nixos-hardware
          hardware.nixosModules.framework-12th-gen-intel
          # > Our main nixos configuration file <
          ./framework/configuration.nix
        ];
      };
      # Desktop PC - Gigabyte Z390 Designare + Intel Core i7-9700k (2019)
      nixos-2022-desktop = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          ./desktop-z390-9700k/configuration.nix
        ];
      };
      # New Storage Server - Z77 + Intel Core i5-3770k (2012)
      yoshi = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; }; # Pass flake inputs to our config
        modules = [
          ./hosts/yoshi/configuration.nix
        ];
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      "samh@fwnixos" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = { inherit inputs; }; # Pass flake inputs to our config
        # > Our main home-manager configuration file <
        modules = [ ./home-manager/home.nix ];
      };
    };
  };
}
