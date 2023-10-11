{ inputs, config, lib, pkgs, ... }:

# Common options for systems with a graphical desktop.
{
  #users.users.samh.extraGroups = [ "libvirtd" ];

  # Enable sound.
  sound.enable = lib.mkDefault true;
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
  # Note: more fonts are in common-options.nix
  fonts.fonts = with pkgs; [
    # Beautiful and free fonts for many languages
    # https://fonts.google.com/noto
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    liberation_ttf
  ];
  fonts.enableDefaultFonts = true;
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

  environment.systemPackages = with pkgs; [
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
    gsmartcontrol
    pavucontrol
    xorg.xkill
  ];
}
