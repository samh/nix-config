# Xfce Desktop Environment
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.gui.xfce;
  x11Packages = import ./x11-packages.nix {inherit pkgs;};
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
    programs.gnupg.agent.enable = lib.mkForce false;

    # Enable the Xfce Desktop Environment.
    services.xserver.desktopManager.xfce.enable = true;
    services.gnome.gnome-keyring.enable = lib.mkDefault true;
    security.pam.services.lightdm.enableGnomeKeyring = lib.mkDefault true;
    programs.seahorse.enable = config.services.gnome.gnome-keyring.enable;

    # https://nixos.wiki/wiki/Thunar
    programs.thunar.enable = true;
    programs.thunar.plugins = with pkgs; [
      thunar-archive-plugin
      thunar-media-tags-plugin
      thunar-volman
    ];
    services.gvfs.enable = true; # Mount, trash, and other functionalities

    # For Flatpak; doesn't seem to be needed when KDE Plasma is enabled.
    xdg.portal.enable = true;

    environment.systemPackages = with pkgs;
      [
        galculator # GTK calculator
        #pavucontrol # Audio mixer
        rofi # Launcher
        ulauncher # Launcher, comparing this and rofi
        xfce4-panel-profiles
        xfce4-whiskermenu-plugin
      ]
      ++ x11Packages;
  };
}
