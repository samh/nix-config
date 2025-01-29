{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  ...
}: let
  steam = config.my.gui.enable;
in {
  imports = [
    ../../include/common-gui.nix
  ];
  config = lib.mkMerge [
    (lib.mkIf config.my.gui.enable {
      my.gui.sound.enable = true;
      # hardware.graphics.enable = true;
      # services.xserver.videoDrivers = ["nvidia"];
      # hardware.nvidia.open = false; # Set to false for proprietary drivers

      # Enable the GNOME Desktop Environment.
      services.xserver.displayManager.gdm.enable = true;
      services.xserver.desktopManager.gnome.enable = true;

      # Configure keymap in X11
      services.xserver = {
        xkb.layout = "us";
        xkb.variant = "";
      };

      # Enable automatic login for the user.
      services.displayManager.autoLogin.enable = true;
      services.displayManager.autoLogin.user = "samh";
      # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
      systemd.services."getty@tty1".enable = false;
      systemd.services."autovt@tty1".enable = false;

      environment.systemPackages = with pkgs; [
        firefox
      ];
    })
    (lib.mkIf steam {
      # Enable Steam
      programs.steam = {
        enable = true;
        remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      };
      programs.steam.gamescopeSession.enable = true;
      programs.gamescope.enable = true;
      programs.gamemode.enable = true; # https://nixos.wiki/wiki/Gamemode
    })
  ];
}
