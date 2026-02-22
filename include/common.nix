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
  options = {
    my.pool.allowWheel = lib.mkEnableOption "Allow wheel group access to /pool";
  };
  config = {
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
    users.groups.multimedia.gid = config.my.metadata.gids.multimedia;
    # Group for access to /storage (probably read-only)
    users.groups.storage.gid = config.my.metadata.gids.storage;
    # Users shown in the login list in the greeter (at least for LightDM)
    users.groups.greeter.gid = config.my.metadata.gids.greeter;

    # Define a user account. Don't forget to set a password with ‘passwd’.
    users.users.samh = {
      uid = 1000;
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "audio"
        "dialout" # for USB serial devices (e.g. ESP32 for ESPHome)
        "greeter"
        "multimedia"
        "networkmanager"
        # Scanner support - https://nixos.wiki/wiki/Scanners
        "scanner"
        "storage"
        "lp"
      ];
      # Note: stored in /etc/ssh/authorized_keys.d/, not ~/.ssh/authorized_keys
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFUXbz1JybJ80kgBWGFG8a0QOjmeMfpCH7l4uZTZTCo7 fedora2020desktop-2022-02-05"
      ];
      # mkDefault (which is mkOverride 1000) doesn't work here; looks like
      # it conflicts with the built-in default user shell.
      shell = lib.mkOverride 999 pkgs.fish;

      # Generally I want to be able to start user services at boot
      linger = lib.mkDefault true;
    };

    # "Only allow members of the wheel group to execute sudo by setting the
    # executable’s permissions accordingly. This prevents users that are not
    # members of wheel from exploiting vulnerabilities in sudo such as
    # CVE-2021-3156."
    # Downside is it doesn't give a good error message when a user is not
    # allowed to sudo; it says this:
    # "sudo: /run/current-system/sw/bin/sudo must be owned by uid 0 and have the setuid bit set"
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
      # Allow my user for remote builds
      # see https://nixos.wiki/wiki/Nixos-rebuild
      # to fix errors like:
      #   "error: cannot add path '/nix/store/...' because it lacks a signature by a trusted key"
      # Also to use custom substituters
      trusted-users = ["root" "samh"];
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
      isd # systemd TUI
      just
      ncdu
      nh # Yet another nix cli helper
      ntfs3g
      psmisc # A set of small useful utilities that use the proc filesystem (such as fuser, killall and pstree)
      pv # monitor progress of data through a pipe
      python3
      ripgrep
      smartmontools
      sshfs
      tmux
      tree
      usbutils # lsusb
      unzip
      #vim
      wget
      zip

      # Custom dfh script - either run by itself or with an argument.
      # "--target" makes it find the mount point associated with the target.
      (pkgs.writeShellScriptBin "dfh" ''
        if [ $# -eq 0 ]; then
          findmnt -t fuse.mergerfs,fuse.rclone,xfs,ext4,btrfs,bcachefs,zfs,vfat --df
        else
          findmnt -t fuse.mergerfs,fuse.rclone,xfs,ext4,btrfs,bcachefs,zfs,vfat --df --target "$1"
        fi
      '')
    ];

    # Make shells available
    programs.fish.enable = true;
    programs.zsh.enable = true;

    # Add some common shell aliases
    environment.shellAliases = {
      "dfh." = "dfh .";
      mounts = "findmnt -t fuse.mergerfs,fuse.rclone,xfs,ext4,btrfs,bcachefs,zfs,vfat";
      psf = "ps -ef | grep";
    };

    programs.tmux = {
      enable = true;
      plugins = with pkgs.tmuxPlugins; [continuum resurrect];
    };

    # Allow using FUSE filesystems across users, especially e.g. bindfs.
    programs.fuse.userAllowOther = true;

    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = lib.mkDefault true;
      settings = {
        PermitRootLogin = lib.mkDefault "no";
        PasswordAuthentication = lib.mkDefault false;
        #AllowGroups = "sshusers";
        #Match = {
        #  Group = "wheel";
        #  PasswordAuthentication = "yes";
        #};
      };
    };
    # GNOME enables gcr-ssh-agent; keep classic ssh-agent for non-GNOME hosts.
    programs.ssh.startAgent = lib.mkDefault (!config.services.desktopManager.gnome.enable);

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

    # Enable firmware update daemon (LVFS); see https://nixos.wiki/wiki/Fwupd
    services.fwupd.enable = true;

    # Disable wait online as it's causing trouble at rebuild
    # See: https://github.com/NixOS/nixpkgs/issues/180175
    systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

    networking.search = [config.my.baseDomain config.my.tailscaleDomain];

    # I like to have these directories around for mounts.
    # Adding them here creates the directories as needed, plus declaratively
    # sets the permissions (/pool should be readable only by root).
    systemd.tmpfiles.rules = [
      "d /media 0755 root root"
      "d /mnt 0755 root root"
      "d /pool ${
        if config.my.pool.allowWheel
        then "0750 root wheel"
        else "0700 root root"
      }"
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
  };
}
