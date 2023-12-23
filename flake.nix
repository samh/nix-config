{
  # Nix configurations; flake initially based on
  # https://github.com/Misterio77/nix-starter-configs
  # (See also https://github.com/misterio77/nix-config)
  description = "My personal nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    # Home manager
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hardware.url = "github:nixos/nixos-hardware";

    samh-shared.url = "github:samh/nix-config-shared";
    samh-shared.inputs.nixpkgs.follows = "nixpkgs";
    samh-shared.inputs.home-manager.follows = "home-manager";
    samh-shared.inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    # nix-colors.url = "github:misterio77/nix-colors";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    hardware,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # Your custom packages
    # Acessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    # NixOS configuration entrypoint
    # Available through 'nixos-rebuild --flake .#your-hostname'
    # (defaults to system hostname if not specified, and if
    # /etc/nixos/flake.nix exists then that will be used without
    # needing the "--flake" option).
    nixosConfigurations = {
      # Framework Laptop
      fwnixos = nixpkgs.lib.nixosSystem {
        # Pass flake inputs to our config. This means that the 'inputs' and
        # 'outputs' variables defined in this file are accessible by our
        # modules if they declare 'inputs' and 'outputs' as arguments.
        specialArgs = {inherit inputs outputs;};
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
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/desktop-z390-9700k/configuration.nix
        ];
      };
      # New Storage Server - Z77 + Intel Core i5-3770k (2012)
      yoshi = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/yoshi/configuration.nix
        ];
      };
      # Dell OptiPlex 7050 Micro - Intel Core i5 i5-6600T (purchased 2023)
      kirby = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/kirby/configuration.nix
        ];
      };
      # Raspberry Pi 3, "pokey" (https://www.mariowiki.com/Pokey)
      pokey = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/pokey/configuration.nix
        ];
      };
      # Test VM on my desktop PC
      goomba = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/goomba/configuration.nix
        ];
      };
      # Old PC - Q6600
      birdo = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/birdo/configuration.nix
        ];
      };
      # Router - Dell OptiPlex 5080 SFF - Intel Core i5-10500 (purchased 2023)
      lakitu = nixpkgs.lib.nixosSystem {
        specialArgs = {inherit inputs outputs;};
        modules = [
          ./hosts/lakitu/configuration.nix
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
      "samh@nixos-2022-desktop" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [./home-manager/nixos-2022-desktop.nix];
      };
      "samh@fwnixos" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [./home-manager/fwnixos.nix];
      };
      "samh" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        # > Our main home-manager configuration file <
        modules = [./home-manager/generic.nix];
      };
    };
  };
}
