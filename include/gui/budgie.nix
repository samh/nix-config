# This file contains various optional configurations, which can be enabled
# or disabled per-host.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.gui.budgie;
in {
  options = {
    my.gui = {
      budgie.enable = mkEnableOption "Budgie desktop";
    };
  };
  imports = [
    ../common-gui.nix
  ];

  config = mkIf cfg.enable {
    my.gui.enable = lib.mkDefault true;
    my.gui.sound.enable = lib.mkDefault true;
    services.xserver.enable = true;
    # Budgie added about 2.6GB (2023-12-12 on NixOS 23.11)
    services.xserver.desktopManager.budgie.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    environment.budgie.excludePackages = with pkgs; [
      vlc
    ];
  };
}
