# Xfce Desktop Environment
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.gui.xfce;
in {
  options = {
    my.gui.xfce.enable = lib.mkEnableOption "Xfce desktop";
  };

  imports = [
    ../common-gui.nix
  ];

  config = lib.mkIf cfg.enable {
    # Enable the X11 windowing system.
    my.gui.enable = lib.mkDefault true;
    my.gui.sound.enable = lib.mkDefault true;

    # Enable the Xfce Desktop Environment.
    services.xserver.desktopManager.xfce.enable = true;
    # https://nixos.wiki/wiki/Thunar
    programs.thunar.enable = true;
    programs.thunar.plugins = with pkgs.xfce; [
      thunar-archive-plugin
      thunar-media-tags-plugin
      thunar-volman
    ];
    services.gvfs.enable = true; # Mount, trash, and other functionalities

    # For Flatpak; doesn't seem to be needed when KDE Plasma is enabled.
    xdg.portal.enable = true;

    environment.systemPackages = with pkgs; [
      galculator # GTK calculator
      xfce.xfce4-panel-profiles
      xfce.xfce4-whiskermenu-plugin
      xorg.xhost
    ];
  };
}
