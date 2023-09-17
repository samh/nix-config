{ config, pkgs, ... }:

# Xfce Desktop
{
  # Enable the Xfce Desktop Environment.
  services.xserver.desktopManager.xfce.enable = true;
  programs.thunar.enable = true;

  environment.systemPackages = with pkgs; [
    xfce.xfce4-panel-profiles
    xfce.xfce4-whiskermenu-plugin
    xorg.xhost
  ];
}
