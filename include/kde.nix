{
  config,
  lib,
  pkgs,
  ...
}:
# KDE Plasma
{
  imports = [
    ./common-gui.nix
  ];

  my.gui.sound.enable = lib.mkDefault true;
  services.xserver.enable = true;

  # Enable the Plasma 6 Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  environment.systemPackages = with pkgs; [
    k4dirstat # disk usage analyzer (qdirstat is also available)
    kdePackages.ark # archive manager
    kdePackages.discover # software center (for Flatpak, lvfs/fwupd)
    kdePackages.kate # includes kwrite
    kdePackages.kcalc # calculator
    kdePackages.kcharselect # character map
    xorg.xhost

    # Try to fix missing icons in some GTK applications like virt-manager,
    # virt-viewer.
    adwaita-icon-theme
    # breeze-icons
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
