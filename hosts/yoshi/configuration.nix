# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../include/common.nix
    ../include/dns-blocky.nix
    ../include/ext-mounts.nix
    ../../include/metadata.nix
    ../include/nextcloud.nix
    ../include/nginx.nix
    ../include/xfce.nix
    #../include/virt-manager.nix
    ./acme.nix
    ./borg-backup.nix
    ./ersatztv.nix
    ./jellyfin.nix
    ./mounts.nix
    ./nvidia-660ti.nix
    ./samba.nix
    ./syncthing.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the grub boot loader (EFI mode)
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = true;
    configurationLimit = 25;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Load the kernel module for the Blu-Ray drive.
  # Found from https://discourse.nixos.org/t/makemkv-cant-find-my-usb-blu-ray-drive/23714/3
  boot.kernelModules = ["sg"];

  networking.hostName = "yoshi"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # RDP remote desktop
  services.xrdp = {
    enable = true;
    openFirewall = false; # Use SSH tunnel (Remmina has built-in support)
    defaultWindowManager = "xfce4-session";
  };

  security.polkit.enable = true;
  # Try to remove prompts when executing Flatpak from RDP.
  # Removing the check "subject.local == true" allows it to work from a remote
  # session like RDP (possibly also e.g. SSH).
  # See https://github.com/flatpak/flatpak/issues/4267
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.Flatpak.app-install" ||
             action.id == "org.freedesktop.Flatpak.runtime-install"||
             action.id == "org.freedesktop.Flatpak.app-uninstall" ||
             action.id == "org.freedesktop.Flatpak.runtime-uninstall" ||
             action.id == "org.freedesktop.Flatpak.modify-repo") &&
            subject.active == true &&
            subject.isInGroup("wheel")) {
                return polkit.Result.YES;
        }
        return polkit.Result.NOT_HANDLED;
    });
  '';

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    android-file-transfer
    bat # cat with syntax highlighting
    bwm_ng # console network/disk monitor
    dua # Disk Usage Analyzer (ncdu alternative)
    firefox
    git # required for building flakes
    gparted
    intel-gpu-tools # intel_gpu_top for checking Jellyfin transcoding
    lshw
    mergerfs
    mergerfs-tools
    nh # Yet another nix cli helper
    pciutils # lspci
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    yt-dlp
    pkgs.unstable.makemkv
  ];

  # List services that you want to enable:

  # Enable vaapi on OS-level for Jellyfin transcoding
  # From https://wiki.nixos.org/wiki/Jellyfin
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  };
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      # vpl-gpu-rt # QSV on 11th gen or newer
      intel-media-sdk # QSV up to 11th gen
      intel-vaapi-driver
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
    ];
  };

  # nginx for reverse proxy
  my.nginx = {
    enable = true;
    openFirewall = true;
  };

  my.common.podman.enable = true;
  #virtualisation.oci-containers.backend = "podman";

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # Local (personal) configuration settings
  # (see common-options.nix)
  my.common.tailscale.enable = true;

  services.tailscale.port = 41642;

  # Enable DNS server.
  # yoshi serves as a backup DNS server for the network in case kirby goes down.
  my.dns.blocky = {
    enable = true;
    openFirewall = true;
  };

  # Group for access to /storage (probably read-only)
  users.groups.storage.gid = config.my.metadata.gids.storage;
  # Group for access to Calibre libraries
  users.groups.calibre.gid = config.my.metadata.gids.calibre;
  # Add my user to groups for storage, calibre, audiobookshelf
  users.users."${config.my.user}".extraGroups = ["storage" "calibre" "audiobookshelf"];

  # Enable Nextcloud
  my.nextcloud.enable = true;

  # Calibre (eBook management)
  # calibre-server is the built-in web server; calibre-web is a third-party web interface
  services.calibre-server.enable = true;
  #services.calibre-server.package = pkgs.unstable.calibre; # use latest version
  services.calibre-server.libraries = [
    # The module doesn't work with spaces in the path.
    # I added a symlink.
    #"/storage/Books/Calibre-Work/Calibre Library"
    "/storage/Books/Calibre-Work-Library"
  ];
  services.calibre-server.auth.enable = true;
  services.calibre-server.auth.mode = "basic";
  services.calibre-server.auth.userDb = "/var/lib/calibre-server/server-users.sqlite";
  services.calibre-server.group = "calibre";
  # I'm trying ACLs first instead of adding another group to the calibre-server user.
  # setfacl -m g:calibre:rx /storage
  #users.users."${config.services.calibre-server.user}".extraGroups = ["storage"];
  services.calibre-server.port = 8085;
  services.nginx.virtualHosts."calibre" = {
    serverName = "calibre.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.calibre-server.port}";
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
  };

  services.audiobookshelf = {
    enable = true;
    port = 8086;
  };
  services.nginx.virtualHosts."audiobookshelf" = {
    serverName = "audiobookshelf.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.audiobookshelf.port}";
      proxyWebsockets = true;
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
  };

  # S.M.A.R.T. monitoring with web interface
  services.scrutiny = {
    enable = true;
    collector.enable = true;
    settings = {
      web.listen.host = "127.0.0.1";
      web.listen.port = 8087;
      web.influxdb.port = 8088;
    };
  };
  services.influxdb2.settings.http-bind-address = "127.0.0.1:8088";
  services.nginx.virtualHosts."scrutiny" = {
    serverName = "scrutiny.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.scrutiny.settings.web.listen.port}";
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
