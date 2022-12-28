# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [
      # A collection of NixOS modules covering hardware quirks.
      # https://github.com/NixOS/nixos-hardware
      <nixos-hardware/framework/12th-gen-intel>
      /etc/nixos/include/common.nix
      /etc/nixos/include/ext-mounts.nix
      /etc/nixos/include/kde.nix
      /etc/nixos/include/virt-manager.nix
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Default mode cuts off a lot of info
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.efi.canTouchEfiVariables = true;

  # Boot parameters for Framework laptop per
  # https://dov.dev/blog/nixos-on-the-framework-12th-gen
  #boot.kernelPackages = pkgs.linuxPackages_6_0;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "module_blacklist=hid_sensor_hub" ];

  networking.hostName = "fwnixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/New_York";

  hardware.bluetooth.enable = true;

  # xpadneo - https://github.com/atar-axis/xpadneo
  # Driver for using Xbox One controller via Bluetooth.
  hardware.xpadneo.enable = true;
  # xone - https://github.com/medusalix/xone
  # Driver for using Xbox One controllers via USB or Xbox Wireless Dongle
  hardware.xone.enable = true;

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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # HiDPI (makes the console font bigger)
  hardware.video.hidpi.enable = true;

  # Enable the GNOME Desktop Environment.
  #services.xserver.displayManager.gdm.enable = true;
  #services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Enable ZRAM swap
  #zramSwap.enable = true;
  #zramSwap.algorithm = "zstd";
  #zramSwap.memoryPercent = 50;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    extraConfig = ''
      # Restrict SSH to only these users
      AllowUsers samh
    '';
  };
  programs.ssh.startAgent = true;
  # Enable Tailscale
  services.tailscale.enable = true;
  # Enable periodic TRIM for SSDs
  services.fstrim.enable = true;
  # Enable firmware update daemon; see https://nixos.wiki/wiki/Fwupd
  services.fwupd.enable = true;

  services = {
    syncthing = {
      enable = true;
      user = "samh";
      dataDir = "/home/samh/Documents";    # Default folder for new synced folders
      configDir = "/home/samh/.config/syncthing";   # Folder for Syncthing's settings and keys

      # Open firewall ports
      openDefaultPorts = true;

      overrideDevices = true;     # overrides any devices added or deleted through the WebUI
      overrideFolders = true;     # overrides any folders added or deleted through the WebUI
      devices = {
        "storage-server-2021" = { id = "AL433J4-2HM6N7D-C4HP5FT-6FNPCPI-MYW4T36-7RIEF5B-7J66U2W-BYW7CQ3"; };
        "fedora2020desktop" = { id = "4JP4C67-VSQX646-E4BRJDC-ZQ2ZTNJ-CKWNUSS-2FC46OK-MDN7DB7-JCKBXQW"; };
        "pixel4a" = { id = "NPVNVC5-J2CKZF6-6LUH6NF-3NYG6GP-GUERNAO-O35UZUC-L6ADKSK-SPRA3AL"; };
      };
      folders = {
        "Sync-Linux" = {        # Name of folder in Syncthing, also the folder ID
          id = "Sync-Linux";
          enable = true;
          path = "/home/samh/Sync";    # Which folder to add to Syncthing
          devices = [ "fedora2020desktop" ];      # Which devices to share the folder with
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "365";  # Syncthing doc says days; is Nix version the same?
#              versionsPath = ".stversions";
            };
          };
        };
        "Notes-Shared" = {
          id = "evgke-fvs53";
          enable = true;
          path = "/home/samh/Notes/Notes-Shared";
          devices = [ "fedora2020desktop" "pixel4a" ];
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "365";
            };
          };
        };
        "Notes-Personal" = {
          id = "jjbsv-stmrg";
          enable = true;
          path = "/home/samh/Notes/Notes-Personal";
          devices = [ "fedora2020desktop" "pixel4a" ];
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "365";
            };
          };
        };
      };
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # Local (personal) configuration settings
  local.common.ansible.enable = true;
  local.common.extras.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

}

