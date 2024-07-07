# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../include/common.nix
    ../include/ext-mounts.nix
    ../include/kde.nix
    ../include/nix-ld.nix
    ../include/virt-manager.nix

    ./borg-backup.nix
    ./mounts.nix
    ./syncthing.nix

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Grub boot loader
  # https://nixos.wiki/wiki/Dual_Booting_NixOS_and_Windows
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.configurationLimit = 25;
  # Try to boot Windows by default. Another option would be to set to
  # "saved" to boot the previously-used option.
  boot.loader.grub.default = 2;

  # Boot parameters for Framework laptop per
  # https://dov.dev/blog/nixos-on-the-framework-12th-gen
  #boot.kernelPackages = pkgs.linuxPackages_6_7; # latest was giving errors with xone driver
  #boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPackages = pkgs.linuxPackages_xanmod;
  boot.kernelParams = ["module_blacklist=hid_sensor_hub"];

  # Enable binfmt emulation of aarch64-linux (to allow building SD card images
  # for Raspberry Pi).
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  networking.hostName = "fwnixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  networking.hosts = {
    "${config.my.metadata.vms.stalfos.internal_ip}" = ["stalfos"];
  };

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
  i18n.inputMethod = {
    enabled = "kime";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

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
  services.printing.drivers = [pkgs.hplip];

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Enable ZRAM swap
  zramSwap.enable = true;
  zramSwap.algorithm = "zstd";
  zramSwap.memoryPercent = 25;

  # Set shell to zsh for testing fleek
  #users.users."${config.my.user}".shell = pkgs.zsh;

  # Define a user account.
  # Initial setup - see NixOS manual:
  # 1. Initial login: su - grace -c "true"
  # 2. Set a password: passwd grace
  users.users.grace = {
    uid = 1009;
    isNormalUser = true;
    home = "/home/grace";
    extraGroups = [
      "audio"
      "networkmanager"
    ];
    shell = pkgs.fish;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    android-file-transfer
    fossil
    nextcloud-client
    nixos-generators
    # syncthingtray Plasmoid issue:
    # https://github.com/NixOS/nixpkgs/issues/199596
    syncthingtray-minimal

    # Using system-level Firefox for now (see more notes in common.nix).
    firefox
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = false;
    withPython3 = false;
    withRuby = false;
  };

  # List services that you want to enable:

  # Disable btrfs auto-scrub, because I don't think it takes into account
  # whether we're on battery power - something to look into. Also it doesn't
  # auto-resume if cancelled because of a suspend (should be possible, I
  # think - there is a 'btrfs scrub resume' command).
  #
  # See:
  # - Discussion about not preventing suspend/shutdown:
  #   https://github.com/NixOS/nixpkgs/pull/80141
  # - Module:
  #   https://github.com/symphorien/nixpkgs/blob/master/nixos/modules/tasks/filesystems/btrfs.nix
  services.btrfs.autoScrub.enable = false;

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
  # (see common-options.nix)
  my.common.ansible.enable = true;
  my.common.extra-fonts.enable = true;
  my.common.extras.enable = true;
  my.common.podman.enable = true;
  my.common.tailscale.enable = true;

  # Mount a magic /usr/bin to make shebangs work
  # https://github.com/Mic92/envfs
  services.envfs.enable = true;

  # Gaming
  programs.steam.enable = true;
  programs.steam.gamescopeSession.enable = true;
  programs.gamescope.enable = true;
  programs.gamemode.enable = true; # https://nixos.wiki/wiki/Gamemode

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
}
