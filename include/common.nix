{ inputs, config, lib, pkgs, ... }:

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
      "wheel" "audio" "networkmanager"
      # Scanner support - https://nixos.wiki/wiki/Scanners
      "scanner" "lp"
    ];
    # mkDefault (which is mkOverride 1000) doesn't work here; looks like
    # it conflicts with the built-in default user shell.
    shell = lib.mkOverride 999 pkgs.fish;
  };

  nix = {
    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Deduplicate and optimize nix store
      auto-optimise-store = true;
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
    pipx # looks like NixOS unstable has "pipx"
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
    plugins = with pkgs.tmuxPlugins; [ continuum resurrect ];
  };

  # Allow using FUSE filesystems across users, especially e.g. bindfs.
  programs.fuse.userAllowOther = true;

  # Disable wait online as it's causing trouble at rebuild
  # See: https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

  boot.kernel.sysctl = {
    # for Syncthing
    # https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size
    "net.core.rmem_max" = 2500000;
  };
}
