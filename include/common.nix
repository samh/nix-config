{
  inputs,
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
  ];

  time.timeZone = "America/New_York";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.samh = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "audio"
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

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: {flake = value;}) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store
      auto-optimise-store = true;
      # Restrict who is allowed to use nix
      allowed-users = ["@wheel"];
    };
  };

  # Automatic Garbage Collection
  # To run manually with a different timeframe:
  # sudo nix-collect-garbage --delete-older-than 7d
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 365d";
  };

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
    borgbackup
    borgmatic
    btdu # btrfs usage tool
    btrbk
    compsize # btrfs compression report
    cryptsetup
    duf
    file
    git
    htop
    ncdu
    ntfs3g
    psmisc # A set of small useful utilities that use the proc filesystem (such as fuser, killall and pstree)
    pipx
    pv # monitor progress of data through a pipe
    python3
    restic
    smartmontools
    sshfs
    tmux
    tree
    usbutils # lsusb
    unzip
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
      AllowUsers samh
    '';
  };
  programs.ssh.startAgent = true;

  # Enable periodic TRIM for SSDs
  services.fstrim.enable = true;
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

  # Add to /etc/hosts. Would like to make this generated from some common
  # metadata, maybe like the TOML file in used by
  # https://github.com/Xe/nixos-configs.git.
  # I don't like the duplication of the service names for the subdomains.
  # Probably keeping those in DNS (as a wildcard), once that is up and
  # running, will be sufficient.
  networking.extraHosts = let
    dom = config.local.base_domain;
    fqdn = "kirby.${config.local.base_domain}";
  in ''
    192.168.5.50 kirby.${dom} kirby
    192.168.5.50 paperless.kirby.${dom}
    192.168.5.50 uptime-kuma.kirby.${dom}
  '';
}
