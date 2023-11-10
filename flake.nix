{
  # Nix configurations; flake initially based on
  # https://github.com/Misterio77/nix-starter-configs
  # (See also https://github.com/misterio77/nix-config)
  description = "My personal nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    nix-config-shared.url = "github:samh/nix-config-shared";
    nix-config-shared.inputs.nixpkgs.follows = "nixpkgs";
    nix-config-shared.inputs.home-manager.follows = "home-manager";
    # Make sure unstable also follows, if we add it as a direct input.
    # nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = {
    nixpkgs,
    home-manager,
    hardware,
    ...
  } @ inputs: {
    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    # (defaults to system hostname if not specified, and if
    # /etc/nixos/flake.nix exists then that will be used without
    # needing the "--flake" option).
    nixosConfigurations = {
      # Framework Laptop
      fwnixos = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;}; # Pass flake inputs to our config
        modules = [
          # A collection of NixOS modules covering hardware quirks.
          # https://github.com/NixOS/nixos-hardware
          hardware.nixosModules.framework-12th-gen-intel
          # > Our main nixos configuration file <
          ./hosts/framework/configuration.nix
        ];
      };
      # Desktop PC - Gigabyte Z390 Designare + Intel Core i7-9700k (2019)
      nixos-2022-desktop = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;}; # Pass flake inputs to our config
        modules = [
          ./hosts/desktop-z390-9700k/configuration.nix
        ];
      };
      # New Storage Server - Z77 + Intel Core i5-3770k (2012)
      yoshi = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;}; # Pass flake inputs to our config
        modules = [
          ./hosts/yoshi/configuration.nix
        ];
      };
      # Dell OptiPlex 7050 Micro - Intel Core i5 i5-6600T (2023)
      kirby = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;}; # Pass flake inputs to our config
        modules = [
          ./hosts/kirby/configuration.nix
        ];
      };
      # Raspberry Pi 3, "pokey" (https://www.mariowiki.com/Pokey)
      pokey = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs;}; # Pass flake inputs to our config
        modules = [
          ./hosts/pokey/configuration.nix
        ];
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    # If you don't have home-manager installed, try
    # `nix shell nixpkgs#home-manager`.
    homeConfigurations = {
      # Looks like the homeConfigurations can be host-specific, such
      # as samh@yoshi, or just "samh".
      # If I have both, is the host-specific one used?
      "samh" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs;}; # Pass flake inputs to our config
        # > Our main home-manager configuration file <
        modules = [./home-manager/home.nix];
      };
    };
  };
}
