# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./mounts.nix
      /etc/nixos/include/common.nix
      /etc/nixos/include/ext-mounts.nix
      /etc/nixos/include/kde.nix
      /etc/nixos/include/vfio-host.nix
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
    pika-backup  # borg frontend - testing it out
    spice-gtk

    # Using system-level Firefox for now (see more notes in common.nix).
    firefox

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

  # Tailscale VPN
  # "warning: Strict reverse path filtering breaks Tailscale exit node use
  # and some subnet routing setups."
  networking.firewall.checkReversePath = "loose";
  services.tailscale.enable = true;

  # Enable periodic TRIM for SSDs
  services.fstrim.enable = true;
  # Enable firmware update daemon; see https://nixos.wiki/wiki/Fwupd
  services.fwupd.enable = true;

  users.users.vm1 = {
    uid = 5010; # in fedora2020 it was 1001, change to be more unique
    isNormalUser = true;
    extraGroups = [ ];
    shell = pkgs.fish;
  };
  users.users.vm2 = {
    uid = 5050;
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" ];
    shell = pkgs.fish;
  };

  services = {
    syncthing = {
      enable = true;
      user = "samh";
      dataDir = "/home/samh/Documents";    # Default folder for new synced folders
      configDir = "/home/samh/.config/syncthing";   # Folder for Syncthing's settings and keys
      openDefaultPorts = true;

      overrideDevices = true;     # overrides any devices added or deleted through the WebUI
      overrideFolders = true;     # overrides any folders added or deleted through the WebUI
      devices = {
        "storage-server" = { id = "AL433J4-2HM6N7D-C4HP5FT-6FNPCPI-MYW4T36-7RIEF5B-7J66U2W-BYW7CQ3"; };
        "framework-laptop" = { id = "DQ5PQ5T-OEQQGJ5-C67RF4Y-SJR5NIZ-WPFSJQT-YNXFOET-37356WL-P7LWNQH"; };
        "pixel4a" = { id = "NPVNVC5-J2CKZF6-6LUH6NF-3NYG6GP-GUERNAO-O35UZUC-L6ADKSK-SPRA3AL"; };
        "work-laptop" = { id = "ME2B765-2HQWLAO-A7PRWE3-RP44QKE-UIJTZSH-467P3GF-JE7FSWY-ZYCPQQA"; }; # 2013
        "work-laptop-old" = { id = "RNF52NS-62AEXH6-OX6QEAG-ELSLT7R-QLMPMW2-OBQS35Z-ZUDVRUF-PNOH3Q4"; };
        # VFIO VM (Windows) - maybe a Samba shared folder would be better, to
        # avoid having to run Syncthing in the VM.
        # Linux VFIO VMs can use a 9p shared folder from the host.
        "vfio-windows" = { id = "CNJBSUE-KIERN7M-6WKA2YC-OO4EDQB-FKM2YJT-HZIOYOF-WKQ6NPJ-CEAHJAU"; };
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
          devices = [
            "vfio-windows"
            "storage-server"
            "framework-laptop"
            "work-laptop-old"
            "work-laptop"
            "pixel4a"
          ];
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
          devices = [ "vfio-windows" "storage-server" "framework-laptop" "pixel4a" ];
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "365";
            };
          };
        };
        # Calibre work library (technical reference material, including
        # e.g. books, manuals, quick reference cards)
        "Calibre-Work" = {
          id = "nqtzd-2klbn";
          enable = true;
          path = "/samh/Calibre-Work";
          devices = [
            "storage-server"
            "work-laptop"
          ];
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "1000";
            };
          };
        };
      };
    };
  };


  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  # virbr2 is the libvirt host-only interface
  # 4656 = pulseaudio
  networking.firewall.interfaces.virbr2.allowedTCPPorts = [ 4656 ];

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  systemd.tmpfiles.rules = [
    # I like to have these directories around for mounts
    "d /media 0755 root root"
    "d /mnt 0755 root root"
    "d /pool 0700 root root"
  ];

  # Local (personal) configuration settings
  local.common.ansible.enable = true;
  local.common.extras.enable = true;
  local.common.podman.enable = true;

  # nix-ld
  # Testing for using VS Code remote
  # https://nixos.wiki/wiki/Visual_Studio_Code#Remote_SSH
  # Causing error on NixOS 23.05.
#  programs.nix-ld.enable = true;
#  environment.variables = {
#    NIX_LD_LIBRARY_PATH = lib.makeLibraryPath [
#      pkgs.stdenv.cc.cc
#    ];
#    NIX_LD = lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
#  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?

}
