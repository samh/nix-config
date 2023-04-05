{ config, pkgs, ... }:

{
  imports = [
    ./common-options.nix
  ];

  time.timeZone = "America/New_York";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.samh = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "wheel" "audio" "networkmanager" ];
    shell = pkgs.fish;
  };

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  # Pipewire
  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # Enable Flatpak
  services.flatpak.enable = true;
  # For the sandboxed apps to work correctly, desktop integration portals need to be installed.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Enable Flakes
  nix = {
    package = pkgs.nixFlakes; # or versioned attributes like nixVersions.nix_2_8
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
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
    autorestic
    bindfs
    borgbackup
    borgmatic
    btdu # btrfs usage tool
    btrbk
    compsize # btrfs compression report
    cryptsetup
    duf
    file
    # Maybe it's better to run Firefox from a Flatpak, so it can be updated
    # without a rebuild (since updates happen often, and usually contain
    # security fixes).
    #firefox
    git
    gsmartcontrol
    htop
    ncdu
    ntfs3g
    pavucontrol
    psmisc # A set of small useful utilities that use the proc filesystem (such as fuser, killall and pstree)
    python310Packages.pipx # looks like NixOS unstable has "pipx"
    pv
    python3
    restic
    smartmontools
    sshfs
    tmux
    tree
    usbutils # lsusb
    unzip
    wget
    xorg.xkill
    zip
  ];

  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [ continuum resurrect ];
  };

  # Allow using FUSE filesystems across users, especially e.g. bindfs.
  programs.fuse.userAllowOther = true;

  boot.kernel.sysctl = {
    # for Syncthing
    # https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size
    "net.core.rmem_max" = 2500000;
  };
}
