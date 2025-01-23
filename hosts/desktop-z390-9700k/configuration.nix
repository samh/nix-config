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
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # Some alternative kernel options:
  # boot.kernelPackages = pkgs.linuxPackages_lqx;
  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_stable;
  # boot.kernelPackages = pkgs.linuxPackages_zen;

  networking.hostName = "nixos-2022-desktop"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  networking.hosts = {
    "${config.my.metadata.vms.bowser.internal_ip}" = ["bowser"];
  };

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  hardware.bluetooth.enable = true;

  # Enable the X11 windowing system.
  my.gui.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [pkgs.hplip];

  # Enable ZRAM swap
  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";
  zramSwap.memoryPercent = 25;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    android-file-transfer
    btrfs-assistant
    jellyfin-media-player
    kitty # A modern, hackable, featureful, OpenGL based terminal emulator (by Kovid Goyal of Calibre)
    libation # Audible audiobook manager
    libreoffice-qt6-fresh
    nextcloud-client
    nh # Yet another nix cli helper
    # pika-backup  # borg frontend - testing it out

    # qemu / quickemu
    #
    # smbd support issue - see See https://github.com/quickemu-project/quickemu/issues/722
    # Tried "qemu_full" so quickemu can use the smb support, but it seems to
    # add ~1.3GB of dependencies. From nixpkgs source, qemu_full is just qemu
    # with some overrides, so try just adding smbd support? Unforunately, this
    # causes a full compile of qemu since it's not cached (takes a while).
    # After update, overriding quickemu with "qemu = qemu_full" gives an error;
    # maybe it requires qemu_full now? (or maybe you'd need to overrid the
    # other way?)
    qemu_full
    quickemu
    samba # Provides smbd for quickemu
    sops # For editing secrets files
    spice-gtk
    virt-viewer # remote-viewer

    spotify
    syncthing
    vscodium.fhs # VS Code editor (FHS chroot version for using extensions from marketplace)
    zellij # Terminal multiplexer (tmux alternative)

    # Using system-level Firefox for now (see more notes in common.nix).
    firefox

    # Firefox addon development
    #firefox-devedition # doesn't seem to work side by side with regular firefox
    #mitmproxy
    #nodejs_20
  ];
  # TODO: only allow per package
  # Obsidian, PyCharm, maybe others I didn't realize...
  nixpkgs.config.allowUnfree = true;
  #allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #  "obsidian"
  #  "jetbrains.pycharm-professional"
  #  "vscode.fhs"
  #];

  # Set FLAKE environment variable used by "nh"
  environment.variables = {
    FLAKE = "/etc/nixos";
  };

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
    extraGroups = ["wheel" "audio" "multimedia"];
    shell = pkgs.fish;
  };

  # Use nftables instead of iptables for NixOS firewall.
  # NOTE: breaks libvirt DHCP / DNS on virtual interfaces; see below.
  networking.nftables.enable = true;

  # Ports 53/67: Fix libvirt DHCP / DNS not working on its virtual interfaces
  # when using nftables (i.e. VMs cannot get an IP address).
  # See issue: https://github.com/NixOS/nixpkgs/issues/263359
  networking.firewall.interfaces.virbr0 = {
    # 'default' (NAT) network
    allowedTCPPorts = [53];
    allowedUDPPorts = [53 67];
  };
  networking.firewall.interfaces.virbr2 = {
    # 'host-only' network
    # 4656 = pulseaudio
    allowedTCPPorts = [53 4656];
    allowedUDPPorts = [53 67];
  };

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  programs.adb.enable = true;
  users.users.samh.extraGroups = ["adbusers"];

  programs.command-not-found.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = false;
    withPython3 = false;
    withRuby = false;
  };

  programs.firejail.enable = true;
  programs.kdeconnect.enable = true;
  programs.yazi.enable = true;

  # Local (personal) configuration settings
  my.common.ansible.enable = true;
  my.common.extra-fonts.enable = true;
  my.common.extras.enable = true;
  my.common.podman.enable = true;
  my.common.tailscale.enable = true;

  # Mount a magic /usr/bin to make shebangs work
  # https://github.com/Mic92/envfs
  # Seems to be getting stuck sometimes, giving errors e.g.
  # "bash: /usr/bin/env: Transport endpoint is not connected"
  # when trying to run a script with /usr/bin/env as the shebang,
  # so disabling for now.
  #services.envfs.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
