# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./borg-backup.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./mounts.nix
    ./syncthing.nix

    ../include/common.nix
    ../include/ext-mounts.nix
    ../include/kde.nix
    ../include/nix-ld.nix
    ../include/vfio-host.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Default mode cuts off a lot of info
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.efi.canTouchEfiVariables = true;

  # Use the latest kernel instead of the default
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "nixos-2022-desktop"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  hardware.bluetooth.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [pkgs.hplip];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    jellyfin-media-player
    libreoffice-qt
    # pika-backup  # borg frontend - testing it out
    spice-gtk

    # Using system-level Firefox for now (see more notes in common.nix).
    firefox
  ];
  # TODO: only allow per package
  # Obsidian, PyCharm, maybe others I didn't realize...
  nixpkgs.config.allowUnfree = true;
  #allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #  "obsidian"
  #  "jetbrains.pycharm-professional"
  #  "vscode.fhs"
  #];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  users.users.vm1 = {
    uid = 5010; # in fedora2020 it was 1001, change to be more unique
    isNormalUser = true;
    extraGroups = [];
    shell = pkgs.fish;
  };
  users.users.vm2 = {
    uid = 5050;
    isNormalUser = true;
    extraGroups = ["wheel" "audio"];
    shell = pkgs.fish;
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # virbr2 is the libvirt host-only interface
  # 4656 = pulseaudio
  networking.firewall.interfaces.virbr2.allowedTCPPorts = [4656];

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # Local (personal) configuration settings
  local.common.ansible.enable = true;
  local.common.extra-fonts.enable = true;
  local.common.extras.enable = true;
  local.common.podman.enable = true;
  local.common.tailscale.enable = true;

  # Mount a magic /usr/bin to make shebangs work
  # https://github.com/Mic92/envfs
  services.envfs.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
