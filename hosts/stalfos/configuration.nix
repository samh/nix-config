# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../include/common.nix
    ../../include/metadata.nix
    ../../include/gui

    # Import home-manager's NixOS module (i.e. build home-manager profile
    # at the same time as the system configuration with nixos-rebuild)
    inputs.home-manager.nixosModules.home-manager

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the grub boot loader (EFI mode)
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = false; # There's no other OS on this machine.
    configurationLimit = 30;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "stalfos"; # Define your hostname.
  networking.networkmanager.enable = false;
  # Set up static networking, using systemd-networkd
  networking.useDHCP = false;
  systemd.network.enable = true;
  systemd.network.networks."10-enp1s0" = {
    matchConfig.Name = "enp1s0";
    #networkConfig.DHCP = "ipv4";
    address = [
      # configure addresses including subnet mask
      "${config.my.metadata.vms.stalfos.internal_ip}/24"
    ];
    routes = [
      # default route(s)
      {routeConfig.Gateway = "192.168.122.1";}
    ];
    # make the routes on this interface a dependency for network-online.target
    linkConfig.RequiredForOnline = "routable";
  };

  my.gui.sound.enable = true;
  my.gui.xfce.enable = true;

  environment.systemPackages = with pkgs; [
    brave # browser
    firefox
    git # required for building flakes
    keepassxc
    rclone
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # Virtual Machine guest stuff
  services.spice-vdagentd.enable = true;
  services.spice-autorandr.enable = true;

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    users = {
      # Import your home-manager configuration
      samh = import ../../home-manager/generic.nix;
    };
  };

  # List services that you want to enable:

  # nginx for reverse proxy
  #  my.nginx = {
  #    enable = true;
  #    openFirewall = true;
  #  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
