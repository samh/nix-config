{ config, lib, pkgs, ... }:

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
    shell = lib.mkDefault pkgs.fish;
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

  # Fonts
  # https://nixos.wiki/wiki/Fonts
  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    # mplus-outline-fonts.githubRelease
    # dina-font
    # proggyfonts
  ];
  fonts.fontDir.enable = true;

  # Enable scanner support (also needs extra user groups)
  # https://nixos.wiki/wiki/Scanners
  hardware.sane.enable = lib.mkDefault true;
  hardware.sane.extraBackends = [ pkgs.sane-airscan ];
  # WARNING: hplip is downloaded from HP's website and compiled.
  #hardware.sane.extraBackends = [ pkgs.hplipWithPlugin ]; # for HP scanner

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
    # security fixes). Using Home Manager is another possibility.
    #
    # For the flatpak, might want to give access to `~/.mozilla` (to use
    # same profile(s)) and Downloads.
    #
    # Flatpak doesn't seem to work with CJK fonts, so might want to stick
    # to system-level, home-manager, or nix-env.
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

  # Make shells available
  programs.fish.enable = true;
  programs.zsh.enable = true;

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
