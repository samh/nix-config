{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.local.common;
in {
  options.local.common.extras = {
    enable = mkEnableOption "Extra packages";
  };
  options.local.common.ansible = {
    enable = mkEnableOption "Ansible controller";
  };

  config = mkMerge [
    (mkIf cfg.ansible.enable {
      environment.systemPackages = with pkgs; [
        ansible
        libsecret # provides secret-tool
      ];
    })
    (mkIf cfg.extras.enable {
      environment.systemPackages = with pkgs; [
        bitwarden
        bwm_ng # console network/disk monitor
        catclock # provides 'xclock'
        distrobox
        doit
        element-desktop
        gnupg
        #gparted
        jetbrains.pycharm-professional
        junction # choose which application to open links
        keepassxc
        kdiff3
        mpv
        neofetch
        nix-index
        #obsidian  # Installed via Flatpak
        podman-compose
        pulseaudioFull
        rclone
        remmina
        thunderbird
        usbimager  # minimal graphical alternative to e.g. Etcher
        #vim
        vimHugeX # gvim
        vscode.fhs
        #vscodium-fhs
        yadm
      ];

      # TODO: only allow per package
      # Obsidian, PyCharm, maybe others I didn't realize...
      nixpkgs.config.allowUnfree = true;
      #allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      #  "obsidian"
      #  "jetbrains.pycharm-professional"
      #  "vscode.fhs"
      #];
    })
  ];
}