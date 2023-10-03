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
  options.local.common.podman = {
    enable = mkEnableOption "Podman containers";
  };
  options.local.common.ansible = {
    enable = mkEnableOption "Ansible controller";
  };
  options.local.common.tailscale = {
    enable = mkEnableOption "Tailscale VPN";
  };

  config = mkMerge [
    (mkIf cfg.ansible.enable {
      environment.systemPackages = with pkgs; [
        ansible
        ansible-lint
        libsecret # provides secret-tool
        sshpass
        yamllint
      ];
    })
    (mkIf cfg.podman.enable {
      virtualisation = {
        docker.enable = false;
        podman = {
          enable = true;
          # Create a `docker` alias for podman, to use it as a drop-in replacement
          dockerCompat = false;
          # Required for containers under podman-compose to be able to talk to each other.
          defaultNetwork.settings.dns_enabled = true;
        };
      };
      environment.systemPackages = with pkgs; [
        podman-compose
      ];
    })
    (mkIf cfg.tailscale.enable {
      # Tailscale VPN
      # "warning: Strict reverse path filtering breaks Tailscale exit node use
      # and some subnet routing setups."
      networking.firewall.checkReversePath = "loose";
      services.tailscale.enable = true;
    })
    (mkIf cfg.extras.enable {
      environment.systemPackages = with pkgs; [
        alejandra # Nix formatter
        bitwarden
        bwm_ng # console network/disk monitor
        catclock # provides 'xclock'
        # cope provides nice colors for things like lsusb, but it was also
        # breaking "ls" for me. Seems to work fine in nix-shell.
        #cope # A colourful wrapper for terminal programs (Perl)
        distrobox
        doit
        dua # Disk Usage Analyzer (ncdu alternative)
        element-desktop
        filezilla
        fira-code
        gnumake
        gnupg
        gocryptfs
        #gparted
        jetbrains.pycharm-professional
        junction # choose which application to open links
        keepassxc
        kdiff3
        mpv
        neofetch
        nil # Nix LSP
        #nixfmt
        #nerdfonts # has to download a bunch of files from GitHub, extract, etc.
        nix-index
        #obsidian  # Installed via Flatpak
        pre-commit
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
        vorta
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
