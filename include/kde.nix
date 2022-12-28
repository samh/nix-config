{ config, pkgs, ... }:

# KDE Plasma
{
  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  environment.systemPackages = with pkgs; [
    ark # archive manager
    kate # includes kwrite
  ];

  programs.partition-manager.enable = true; # KDE Partition Manager

  # Exclude some KDE Plasma packages
  # https://nixos.wiki/wiki/KDE
  # Attempt to disable kwallet to be able to use KeePassXC's secret service
  #services.xserver.desktopManager.plasma5.excludePackages = with pkgs.libsForQt5; [
  #  kwallet
  #  kwallet-pam
  #  kwalletmanager
  #];
  # Try to override options from
  # https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/services/x11/desktop-managers/plasma5.nix
  # to disable kwallet.
  #security.pam.services.gdm.enableKwallet = pkgs.lib.mkForce false;
  #security.pam.services.kdm.enableKwallet = pkgs.lib.mkForce false;
  #security.pam.services.lightdm.enableKwallet = pkgs.lib.mkForce false;
  #security.pam.services.sddm.enableKwallet = pkgs.lib.mkForce false;
}
