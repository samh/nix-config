{ config, pkgs, ... }:

# Xfce Desktop
{
  imports = [
    ./common-gui.nix
  ];

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Xfce Desktop Environment.
  services.xserver.desktopManager.xfce.enable = true;
  programs.thunar.enable = true;

  # For Flatpak; doesn't seem to be needed when KDE Plasma is enabled.
  xdg.portal.enable = true;

  environment.systemPackages = with pkgs; [
    xfce.xfce4-panel-profiles
    xfce.xfce4-whiskermenu-plugin
    xorg.xhost
  ];
}
