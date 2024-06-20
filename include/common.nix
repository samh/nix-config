{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  ...
}:
# Common - should be things that can be enabled everywhere
# (except maybe very minimal systems?).
# Should not include anything desktop-related (see common-desktop.nix
# for that).
{
  imports = [
    ./common-options.nix
    ./sysctl.nix
  ];

  time.timeZone = lib.mkDefault "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Define a group for access to multimedia files, e.g. videos, music.
  users.groups.multimedia = {
    gid = 20050;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.samh = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "audio"
      "multimedia"
      "networkmanager"
      # Scanner support - https://nixos.wiki/wiki/Scanners
      "scanner"
      "lp"
    ];
    # Note: stored in /etc/ssh/authorized_keys.d/, not ~/.ssh/authorized_keys
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFUXbz1JybJ80kgBWGFG8a0QOjmeMfpCH7l4uZTZTCo7 fedora2020desktop-2022-02-05"
    ];
    # mkDefault (which is mkOverride 1000) doesn't work here; looks like
    # it conflicts with the built-in default user shell.
    shell = lib.mkOverride 999 pkgs.fish;
  };

  # "Only allow members of the wheel group to execute sudo by setting the
  # executable’s permissions accordingly. This prevents users that are not
  # members of wheel from exploiting vulnerabilities in sudo such as
  # CVE-2021-3156."
  security.sudo.execWheelOnly = lib.mkDefault true;

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages # enables "pkgs.unstable.xyz"

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
  };

  # This will add each flake input as a registry
  # To make nix3 commands consistent with your flake
  nix.registry = (lib.mapAttrs (_: flake: {inherit flake;})) ((lib.filterAttrs (_: lib.isType "flake")) inputs);

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = ["/etc/nix/path"];
  environment.etc =
    lib.mapAttrs'
    (name: value: {
      name = "nix/path/${name}";
      value.source = value.flake;
    })
    config.nix.registry;

  nix.settings = {
    # Enable flakes and new 'nix' command
    experimental-features = "nix-command flakes";
    # Deduplicate and optimize nix store
    auto-optimise-store = true;
  };

  # Cleanup - Automatic Garbage Collection
  #
  # To run manually with a different timeframe:
  # sudo nix-collect-garbage --delete-older-than 7d
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 180d";
  };

  # command-not-found doesn't seem to work by default with Flakes; needs
  # manual intervention to add a channel.
  # Disable it until I can find a good, declarative fix.
  programs.command-not-found.enable = lib.mkDefault false;

  # Limit the systemd journal to X MB of disk or the
  # last Y days of logs, whichever happens first.
  # From https://xeiaso.net/blog/morph-setup-2021-04-25/
  services.journald.extraConfig = ''
    SystemMaxUse=200M
    MaxFileSec=14day
  '';

  environment.systemPackages = with pkgs; [
    #autorestic
    bindfs
    btdu # btrfs usage tool
    btop # another top, rewrite of bpytop in C++
    btrbk # even if not using for backups, it provides 'lsbtr' command
    compsize # btrfs compression report
    cryptsetup
    dig
    duf
    file
    git # Required to build flakes
    htop
    ncdu
    nh # Yet another nix cli helper
    ntfs3g
    psmisc # A set of small useful utilities that use the proc filesystem (such as fuser, killall and pstree)
    pipx
    pv # monitor progress of data through a pipe
    python3
    ripgrep
    smartmontools
    sshfs
    tmux
    tree
    usbutils # lsusb
    unzip
    vim
    wget
    zip
  ];

  # Make shells available
  programs.fish.enable = true;
  programs.zsh.enable = true;

  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [continuum resurrect];
  };

  # Allow using FUSE filesystems across users, especially e.g. bindfs.
  programs.fuse.userAllowOther = true;

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    extraConfig = ''
      # Restrict SSH to only these users
      AllowUsers ${config.my.user}
    '';
  };
  programs.ssh.startAgent = true;

  # Enable periodic TRIM for SSDs
  services.fstrim.enable = true;

  # Regularly scrub btrfs filesystems.
  #
  # Make sure not to list duplicates (i.e. multiple mount points that
  # point to the same underlying volume)!
  # To avoid duplicates, use all of the "/pool" mount points, which are
  # (by my personal convention) the top-level subvolumes of each btrfs
  # filesystem.
  #
  # This creates a systemd timer and service for each filesystem, for
  # example:
  #   btrfs-scrub-pool-4TB.2014.2282.timer
  #   btrfs-scrub-pool-4TB.2014.2282.service
  #
  services.btrfs.autoScrub.enable = lib.mkDefault true;
  services.btrfs.autoScrub.interval = "monthly";
  # This will cause a failure if empty, which is what I want for sanity checking.
  services.btrfs.autoScrub.fileSystems = let
    # Get all btrfs filesystems
    btrfsFileSystems = lib.filterAttrs (name: value: value.fsType == "btrfs") config.fileSystems;
    # Get the names (i.e. paths) of those filesystems
    btrfsFileSystemMounts = builtins.attrNames btrfsFileSystems;
    # Find the /pool mount points
    btrfsPoolFileSystems = builtins.filter (x: lib.strings.hasPrefix "/pool/" x) btrfsFileSystemMounts;
    # If /pool mount points exist, use those, otherwise scrub any btrfs filesystems
    scrubFileSystems =
      if builtins.length btrfsPoolFileSystems > 0
      then btrfsPoolFileSystems
      else btrfsFileSystemMounts;
  in
    scrubFileSystems;

  # Enable firmware update daemon; see https://nixos.wiki/wiki/Fwupd
  services.fwupd.enable = true;

  # Disable wait online as it's causing trouble at rebuild
  # See: https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

  # I like to have these directories around for mounts.
  # Adding them here creates the directories as needed, plus declaratively
  # sets the permissions (/pool should be readable only by root).
  systemd.tmpfiles.rules = [
    "d /media 0755 root root"
    "d /mnt 0755 root root"
    "d /pool 0700 root root"
  ];

  boot.kernel.sysctl = {
    # for Syncthing
    # https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size
    "net.core.rmem_max" = 2500000;
  };

  # Set defaults for Let's Encrypt / ACME certificates
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "acme@mail.hartsfield.xyz";
  # The lego tool does some DNS checks and seems to be confused by the
  # internal DNS in some cases (appeared when subdomain was delegated).
  # Related: https://github.com/go-acme/lego/issues/1066#issuecomment-636242733
  security.acme.defaults.dnsResolver = "1.1.1.1:53";
}
