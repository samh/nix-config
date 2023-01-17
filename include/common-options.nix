# This file contains various optional configurations, which can be enabled
# or disabled per-host.

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
        filezilla
        gnupg
        gocryptfs
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
        #rar # seems like it requires downloading a binary from rarlab.com
        rclone
        rclone-browser
        remmina
        shellcheck # shell script linter
        shfmt # shell script formatter
        smplayer
        thunderbird
        unrar
        usbimager  # minimal graphical alternative to e.g. Etcher
        #vim
        vimHugeX # gvim
        vlc
        vscode.fhs
        #vscodium-fhs
        yadm
      ];

      # TODO: only allow per package
      # Obsidian, PyCharm, rar, unrar
      # maybe others I didn't realize...
      nixpkgs.config.allowUnfree = true;
      #allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      #  "obsidian"
      #  "jetbrains.pycharm-professional"
      #  "vscode.fhs"
      #];
    })
  ];
}
