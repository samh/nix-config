{ config, pkgs, ... }:

{
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

  environment.systemPackages = with pkgs; [
    autorestic
    borgbackup
    borgmatic
    btrbk
    cryptsetup
    file
    git
    gsmartcontrol
    ncdu
    ntfs3g
    pavucontrol
    pv
    python3
    restic
    smartmontools
    sshfs
    tmux
    tree
    unzip
    wget
    zip
  ];

  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [ continuum resurrect ];
  };

  boot.kernel.sysctl = {
    # for Syncthing
    # https://github.com/lucas-clemente/quic-go/wiki/UDP-Receive-Buffer-Size
    "net.core.rmem_max" = 2500000;
  };
}
