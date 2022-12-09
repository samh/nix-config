# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./mounts.nix
      /etc/nixos/include/common.nix
      /etc/nixos/include/kde.nix
      /etc/nixos/include/vfio-host.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Default mode cuts off a lot of info
  boot.loader.systemd-boot.consoleMode = "auto";
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos-2022-desktop"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

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
  services.printing.drivers = [ pkgs.hplip ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    bitwarden
    bwm_ng # console network/disk monitor
    doit
    duf
    element-desktop
    firefox
    gnupg
    #gparted
    htop
    jetbrains.pycharm-professional
    kdiff3
    keepassxc
    neofetch
    #obsidian  # Installed via Flatpak
    rclone
    #remmina  # trying Flatpak
    syncthing
    thunderbird
    tmux
    tmuxPlugins.continuum
    tmuxPlugins.resurrect
    #vim
    vimHugeX # gvim
    vscode.fhs
    #vscodium-fhs
    yadm

    # XFCE
    #xfce.xfce4-panel-profiles
    #xfce.xfce4-pulseaudio-plugin
    #xfce.xfce4-whiskermenu-plugin
  ];
  # TODO: only allow per package
  # Obsidian, PyCharm, maybe others I didn't realize...
  nixpkgs.config.allowUnfree = true;
  #allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #  "obsidian"
  #  "jetbrains.pycharm-professional"
  #  "vscode.fhs"
  #];

  programs.partition-manager.enable = true; # KDE Partition Manager

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  programs.ssh.startAgent = true;

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

      overrideDevices = true;     # overrides any devices added or deleted through the WebUI
      overrideFolders = true;     # overrides any folders added or deleted through the WebUI
      devices = {
        "storage-server" = { id = "AL433J4-2HM6N7D-C4HP5FT-6FNPCPI-MYW4T36-7RIEF5B-7J66U2W-BYW7CQ3"; };
        "framework-laptop" = { id = "DQ5PQ5T-OEQQGJ5-C67RF4Y-SJR5NIZ-WPFSJQT-YNXFOET-37356WL-P7LWNQH"; };
        "pixel4a" = { id = "NPVNVC5-J2CKZF6-6LUH6NF-3NYG6GP-GUERNAO-O35UZUC-L6ADKSK-SPRA3AL"; };
        "work-laptop" = { id = "RNF52NS-62AEXH6-OX6QEAG-ELSLT7R-QLMPMW2-OBQS35Z-ZUDVRUF-PNOH3Q4"; };
      };
      folders = {
        "Sync-Linux" = {        # Name of folder in Syncthing, also the folder ID
          id = "Sync-Linux";
          enable = true;
          path = "/home/samh/Sync";    # Which folder to add to Syncthing
          devices = [ "framework-laptop" ];      # Which devices to share the folder with
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
          devices = [ "storage-server" "framework-laptop" "work-laptop" "pixel4a" ];
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
          devices = [ "storage-server" "framework-laptop" "pixel4a" ];
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

  # Console fonts are too big on 2560x1440 monitors with HiDPI enabled
  hardware.video.hidpi.enable = false;

  systemd.tmpfiles.rules = [
    # I like to have these directories around for mounts
    "d /media 0755 root root"
    "d /mnt 0755 root root"
    "d /pool 0700 root root"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

}
