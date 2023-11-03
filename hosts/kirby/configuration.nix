# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
{
  config,
  lib,
  pkgs,
  ...
}: let
  homeAssistantIP = config.my.metadata.vms.homeassistant.internal_ip;
in {
  imports = [
    ../include/common.nix
    ../include/dns-blocky.nix
    ../include/ext-mounts.nix
    ../include/nginx.nix
    ../include/xfce.nix
    ../include/virt-manager.nix

    ./acme.nix
    ./borg-backup.nix
    ./mounts.nix
    ./samba.nix
    ./zigbee2mqtt.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the grub boot loader (EFI mode)
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = false; # There's no other OS on this machine.
    configurationLimit = 30;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Make sure IP forwarding is enabled for Tailscale subnet routing
  # https://tailscale.com/kb/1019/subnets/?tab=linux
  my.sysctl.net.ipv4.ip_forward = true;
  my.sysctl.net.ipv6.conf.all.forwarding = true;

  networking.hostName = "kirby"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Enable the X11 windowing system.
  services.xserver.enable = true;

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
    dua # Disk Usage Analyzer (ncdu alternative)
    firefox
    git # required for building flakes
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # List services that you want to enable:

  # nginx for reverse proxy
  my.nginx = {
    enable = true;
    openFirewall = true;
  };

  services.uptime-kuma.enable = true;
  services.nginx.virtualHosts."uptime-kuma" = {
    serverName = "uptime-kuma.${config.local.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.uptime-kuma.settings.PORT}";
      proxyWebsockets = true;
    };
    forceSSL = true;
    useACMEHost = config.local.hostDomain;
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;
    # Checksums seems like a good idea in general, but if running on
    # btrfs it seems redundant. Arch wiki suggests it "If your database
    # files reside on a file system without checksumming".
    #initdbArgs = [ "--data-checksums"];

    # Potentially worse for security, but for convenience of connecting from GUIs,
    # it may be worth allowing TCP/IP connections.
    enableTCPIP = true;
  };

  # Configure the paperless service.
  #
  # Tried "services.postgresql.ensureUsers" and "services.postgresql.ensureDatabases"
  # but the don't seem to work very well for this, at least not right now. See
  # https://github.com/NixOS/nixpkgs/pull/107342 and various other linked issues.
  # The PostgreSQL user and database need to be created manually.
  services.paperless = {
    enable = true;
    extraConfig = {
      PAPERLESS_URL = "https://paperless.${config.local.hostDomain}";
      PAPERLESS_DBENGINE = "postgresql";
      PAPERLESS_DBHOST = "/run/postgresql";
      PAPERLESS_OCR_LANGUAGE = "eng";
      PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
    };
  };
  services.nginx.virtualHosts."paperless" = {
    serverName = "paperless.${config.local.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.paperless.port}";
    };
    forceSSL = true;
    useACMEHost = config.local.hostDomain;
  };

  # Home Assistant
  # Use nginx to proxy the ports.
  # Could also have used some kind of iptables forwarding
  # but this seemed easier. 'virtualisation.forwardPorts' does
  # *not* work; what about 'networking.nat.forwardPorts'?
  services.nginx.streamConfig = ''
    # MQTT (TCP)
    server {
      listen 1883;
      proxy_pass ${homeAssistantIP}:1883;
    }
    # CoIoT (UDP) - for Shelly gen1 devices
    server {
      listen 5683 udp;
      proxy_pass ${homeAssistantIP}:5683;
    }
  '';
  services.nginx.virtualHosts."ha" = {
    serverName = "ha.${config.local.hostDomain}";
    locations."/" = {
      proxyPass = "http://${homeAssistantIP}:8123";
      proxyWebsockets = true;
    };
    forceSSL = true;
    useACMEHost = config.local.hostDomain;
  };

  #virtualisation.oci-containers.backend = "podman";

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    # MQTT
    1883
  ];
  networking.firewall.allowedUDPPorts = [
    # CoIoT
    5683
  ];

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # Local (personal) configuration settings
  # (see common-options.nix)
  local.common.tailscale.enable = true;

  # Enable DNS server.
  # Serves DNS for the rest of the network.
  my.dns.blocky = {
    enable = true;
    openFirewall = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
