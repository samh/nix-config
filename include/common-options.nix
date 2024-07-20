# This file contains various optional configurations, which can be enabled
# or disabled per-host.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.common;
in {
  options = {
    my.common = {
      extras.enable = mkEnableOption "Extra packages";
      extra-fonts.enable = mkEnableOption "Extra fonts";
      podman.enable = mkEnableOption "Podman containers";
      ansible.enable = mkEnableOption "Ansible controller";
      tailscale.enable = mkEnableOption "Tailscale VPN";
    };
    my.baseDomain = mkOption {
      type = types.str;
      default = "hartsfield.xyz";
      description = "Base domain name for services (option in case we want to override for some testing purpose)";
    };
    my.hostDomain = mkOption {
      type = types.str;
      default = "${config.networking.hostName}.${config.my.baseDomain}";
      description = "Domain name for this host (usually a subdomain of the base domain)";
    };
    my.user = mkOption {
      type = types.str;
      default = "samh";
      description = "My main username";
    };
    my.homeDir = mkOption {
      type = types.str;
      default = "/home/${config.my.user}";
      description = "My home directory";
    };
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
        bat # cat with syntax highlighting
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
        junction # choose which application to open links
        keepassxc
        kdiff3
        mpv
        neofetch
        #nerdfonts # has to download a bunch of files from GitHub, extract, etc.
        nil # Nix LSP
        nix-index # quickly locate the package providing a certain file in nixpkgs
        nix-tree # Interactively browse dependency graphs of Nix derivations.
        #nixfmt
        #obsidian  # Installed via Flatpak
        pre-commit
        pulseaudioFull
        #rar # seems like it requires downloading a binary from rarlab.com
        rclone
        rclone-browser
        remmina
        ruff
        shellcheck # shell script linter
        shfmt # shell script formatter
        smplayer
        thunderbird
        unrar
        usbimager # minimal graphical alternative to e.g. Etcher
        #vim
        #vimHugeX # gvim
        vlc
        vorta # Borg backup GUI
        # VS Code - FHS version "Should allow for easy usage of extensions
        # without nix-specific modifications."
        #vscode.fhs
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

      programs.direnv.enable = true;
    })
    (mkIf cfg.extra-fonts.enable {
      fonts.packages = with pkgs; [
        fira-code
        fira-code-symbols
        d2coding # Monospace font with support for Korean and latin characters
        victor-mono # A programming font with semi-connected cursive italics and symbol ligatures
        # mplus-outline-fonts.githubRelease
        # dina-font
        # proggyfonts

        # Trying to find a variety of fonts for general use
        andika # A family designed especially for literacy use taking into account the needs of beginning readers
        barlow
        carlito # A sans-serif font metric-compatible with Microsoft Calibri
        charis-sil # A family of highly readable fonts for broad multilingual use
        comfortaa # A clean and modern font suitable for headings and logos
        dotcolon-fonts # Font Collection by Sora Sagano
        league-of-moveable-type # Font Collection by The League of Moveable Type https://www.theleagueofmoveabletype.com/
        # linux-libertine # Libertine Fonts is a collection of libre multilingual fonts.
        # open-fonts # A collection of beautiful free and open source fonts
        open-sans
        # recursive # A variable font family for code & UI

        # Roboto: Google’s signature family of fonts, the default font on Android
        # and Chrome OS, and the recommended font for Google’s visual language,
        # Material Design.
        # roboto
        # roboto-serif

        # "The world's biggest collection of classic text mode fonts, system fonts
        # and BIOS fonts from DOS-era IBM PCs and compatibles - preserving raster
        # typography from pre-GUI times"
        # https://int10h.org/oldschool-pc-fonts/
        ultimate-oldschool-pc-font-pack

        unfonts-core # Korean Hangul typeface collection https://kldp.net/unfonts/

        zilla-slab # A custom family for Mozilla by Typotheque
      ];
    })
  ];
}
