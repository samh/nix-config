# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./borg-backup.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./mounts.nix
    #./nvidia-rtx2070.nix
    #./proxy.nix
    ./syncthing.nix
    ./ups.nix

    inputs.sops-nix.nixosModules.sops

    ../include/common.nix
    ../include/ext-mounts.nix
    ../include/kde.nix
    ../include/mounts-yoshi.nix
    ../include/nix-ld.nix
    ../include/numtide-cache.nix
    ../include/vfio-host.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Default mode cuts off a lot of info
  boot.loader.systemd-boot.consoleMode = "max";
  boot.loader.efi.canTouchEfiVariables = true;

  # Linux Kernel
  #
  # NOTE: I was using linuxPackages_zen for a while (6.15), but 6.16 broke NVIDIA drivers
  # (probably temporary), so I changed to xanmod_latest.
  #
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  # Some alternative kernel options:
  # boot.kernelPackages = pkgs.linuxPackages_6_15;
  # boot.kernelPackages = pkgs.linuxPackages_lqx;
  # boot.kernelPackages = pkgs.linuxPackages_xanmod;
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_stable;
  boot.kernelPackages = pkgs.linuxPackages_zen;

  networking.hostName = "nixos-2022-desktop"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  networking.hosts = {
    "${config.my.metadata.vms.bowser.internal_ip}" = ["bowser"];
  };

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };
  i18n.inputMethod = {
    enable = true;
    #type = "kime";
    #type = "ibus";
    #ibus.engines = with pkgs.ibus-engines; [hangul];
    type = "fcitx5";
    fcitx5.addons = with pkgs; [fcitx5-hangul];
  };

  hardware.bluetooth.enable = true;

  hardware.graphics = {
    enable = true;
    # Added for hardware video decoding. Not sure if we need all of these.
    # https://nixos.wiki/wiki/Intel_Graphics
    extraPackages = with pkgs; [
      intel-media-driver
      # vpl-gpu-rt # QSV on 11th gen or newer
      #intel-media-sdk # QSV up to 11th gen
      #intel-vaapi-driver
      #libva-vdpau-driver
      libvdpau-va-gl
      #intel-compute-runtime # adds ~1.2GiB
    ];
  };

  # Enable the X11 windowing system.
  my.gui.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [pkgs.hplip];

  # "Install the SPICE USB redirection helper with setuid privileges.
  # This allows unprivileged users to pass USB devices connected to this
  # machine to libvirt VMs, both local and remote. Note that this allows
  # users arbitrary access to USB devices."
  virtualisation.spiceUSBRedirection.enable = true;

  # Enable ZRAM swap
  #  zramSwap.enable = true;
  #  zramSwap.algorithm = "zstd";
  #  zramSwap.memoryPercent = 10;
  #zramSwap.memoryPercent = 25;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages =
    (with pkgs; [
      android-file-transfer # Uses Qt5
      btrfs-assistant
      docker-compose
      ghostty # Fast, native, feature-rich terminal emulator pushing modern features
      #gollama # Manage ollama models
      #jellyfin-media-player # pulls in Qt5; I don't use this much on desktop
      just
      k4dirstat
      #kitty # A modern, hackable, featureful, OpenGL based terminal emulator (by Kovid Goyal of Calibre)
      libation # Audible audiobook manager
      libreoffice-qt6-fresh
      #lmstudio # LM Studio (AI)
      moonlight-qt
      nextcloud-client
      nixos-rebuild-ng
      nh # Yet another nix cli helper
      pkgs.unstable.podlet # Generate Quadlet files from command/compose
      restic # Backup program
      socat
      sops # For editing secrets files
      spotify
      syncthing
      vscodium.fhs # VS Code editor (FHS chroot version for using extensions from marketplace)
      zellij # Terminal multiplexer (tmux alternative)

      # qemu / quickemu
      #
      # smbd support issue - see See https://github.com/quickemu-project/quickemu/issues/722
      # Tried "qemu_full" so quickemu can use the smb support, but it seems to
      # add ~1.3GB of dependencies. From nixpkgs source, qemu_full is just qemu
      # with some overrides, so try just adding smbd support? Unforunately, this
      # causes a full compile of qemu since it's not cached (takes a while).
      # After update, overriding quickemu with "qemu = qemu_full" gives an error;
      # maybe it requires qemu_full now? (or maybe you'd need to overrid the
      # other way?)
      qemu_full
      quickemu
      samba # Provides smbd for quickemu
      spice-gtk
      virt-viewer # remote-viewer

      # Using system-level Firefox for now (see more notes in common.nix).
      firefox

      # Firefox addon development
      #firefox-devedition # doesn't seem to work side by side with regular firefox
      #mitmproxy
      #nodejs_20
    ])
    ++ (with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      codex
      copilot-cli
      #gemini-cli
      #goose-cli
      #opencode
    ]);

  # TODO: only allow per package
  # Obsidian, PyCharm, maybe others I didn't realize...
  nixpkgs.config.allowUnfree = true;
  #allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #  "obsidian"
  #  "jetbrains.pycharm-professional"
  #  "vscode.fhs"
  #];

  # Set NH_FLAKE environment variable used by "nh"
  environment.variables = {
    NH_FLAKE = "/etc/nixos";
  };

  sops.defaultSopsFile = ../../secrets/secrets.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  sops.age.generateKey = false;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  users.users.vm1 = {
    uid = 5010; # in fedora2020 it was 1001, change to be more unique
    isNormalUser = true;
    extraGroups = [];
    shell = pkgs.fish;
  };
  users.users.vm2 = {
    uid = 5050;
    isNormalUser = true;
    extraGroups = ["wheel" "audio" "multimedia"];
    shell = pkgs.fish;
  };

  # Use nftables instead of iptables for NixOS firewall.
  # NOTE: breaks libvirt DHCP / DNS on virtual interfaces; see below.
  networking.nftables.enable = true;

  # Ports 53/67: Fix libvirt DHCP / DNS not working on its virtual interfaces
  # when using nftables (i.e. VMs cannot get an IP address).
  # See issue: https://github.com/NixOS/nixpkgs/issues/263359
  networking.firewall.interfaces.virbr0 = {
    # 'default' (NAT) network
    allowedTCPPorts = [53];
    allowedUDPPorts = [53 67];
  };
  networking.firewall.interfaces.virbr2 = {
    # 'host-only' network
    # 4656 = pulseaudio
    allowedTCPPorts = [53 4656];
    allowedUDPPorts = [53 67];
  };

  # Allow ollama over tailscale (ollama running in container)
  # WARNING: does not have any authentication
  #  networking.firewall.interfaces.tailscale0 = {
  #    allowedTCPPorts = [11434];
  #  };

  programs.adb.enable = true;
  users.users.samh.extraGroups = ["adbusers"];

  programs.command-not-found.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withNodeJs = false;
    withPython3 = false;
    withRuby = false;
  };

  programs.firejail.enable = true;
  programs.kdeconnect.enable = true;
  programs.yazi.enable = true;

  # TODO: need to adjust permissions or exclusions
  # See journal for update-locatedb.service
  services.locate.enable = true;

  # Local (personal) configuration settings
  my.common.ansible.enable = true;
  my.common.extra-fonts.enable = true;
  my.common.extras.enable = true;
  my.common.podman.enable = true;
  virtualisation.podman.dockerCompat = true;
  my.common.tailscale.enable = true;

  # Mount a magic /usr/bin to make shebangs work
  # https://github.com/Mic92/envfs
  # Seems to be getting stuck sometimes, giving errors e.g.
  # "bash: /usr/bin/env: Transport endpoint is not connected"
  # when trying to run a script with /usr/bin/env as the shebang,
  # so disabling for now.
  services.envfs.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
