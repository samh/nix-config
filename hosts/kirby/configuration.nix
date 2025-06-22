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
  myIP = config.my.metadata.hosts.${config.networking.hostName}.ip_address;
  myTailscaleIP = config.my.metadata.hosts.${config.networking.hostName}.tailscale_address;
in {
  imports = [
    ../include/common.nix
    ../include/dns-blocky.nix
    ../include/ext-mounts.nix
    ../include/nginx.nix
    ../include/virt-manager.nix

    ./acme.nix
    ./borg-backup.nix
    ./forgejo.nix
    ./gitea.nix
    ./mounts.nix
    ./samba.nix
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
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  # Enable Intel VT-d for PCI passthrough (VFIO / IOMMU).
  # I tried this, but the IOMMU groups on this hardware don't seem to be
  # very useful.
  #boot.kernelParams = [
  #  "intel_iommu=on"
  #  "iommu=pt"
  #  "kvm.ignore_msrs=1"
  #  "kvm.report_ignored_msrs=0"
  #];
  # Extra kernel modules required for VFIO
  #boot.kernelModules = ["vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio"];

  networking.hostName = "kirby"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Allow my user for remote builds
  # see https://nixos.wiki/wiki/Nixos-rebuild
  # to fix errors like:
  #   "error: cannot add path '/nix/store/...' because it lacks a signature by a trusted key"
  nix.settings.trusted-users = ["samh"];

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    dua # Disk Usage Analyzer (ncdu alternative)
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
    serverName = "uptime-kuma.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.uptime-kuma.settings.PORT}";
      proxyWebsockets = true;
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
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
    consumptionDir = "/srv/shares/scanner";
    settings = {
      PAPERLESS_URL = "https://paperless.${config.my.hostDomain}";
      PAPERLESS_DBENGINE = "postgresql";
      PAPERLESS_DBHOST = "/run/postgresql";
      PAPERLESS_OCR_LANGUAGE = "eng";
      PAPERLESS_FILENAME_FORMAT = "{created_year}/{correspondent}/{title}";
      PAPERLESS_DATE_ORDER = "MDY";
      # Try to give scanner time to finish writing
      PAPERLESS_CONSUMER_INOTIFY_DELAY = "120";
    };
  };
  users.users.paperless = {
    # Add to scanner group so it can read scanned documents.
    # Primary group is used in the paperless module to set the
    # ownership of the consumption, data, and media directories.
    group = lib.mkForce "inbox";
    extraGroups = ["inbox"];
  };
  services.nginx.virtualHosts."paperless" = {
    serverName = "paperless.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.paperless.port}";
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
  };

  # Karakeep bookmark/read later/archiving app
  services.karakeep = {
    enable = true;
    extraEnvironment = {
      PORT = "3010";
      DISABLE_SIGNUPS = "true";
      DISABLE_NEW_RELEASE_CHECK = "true";
      NEXTAUTH_URL = "keep.${config.my.hostDomain}";
      CRAWLER_FULL_PAGE_ARCHIVE = "true";
    };
  };
  # Use current package instead of deprecated one
  services.meilisearch.package = pkgs.meilisearch;
  services.nginx.virtualHosts."keep" = {
    serverName = "keep.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.karakeep.extraEnvironment.PORT}";
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
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

    # Docker Wyze Bridge add-on
    #  server {
    #    listen 8554; # RTSP
    #    proxy_pass ${homeAssistantIP}:8554;
    #  }
    #  server {
    #    listen 8888; # HLS
    #    proxy_pass ${homeAssistantIP}:8888;
    #  }
    #  server {
    #    listen 8889; # WebRTC
    #    proxy_pass ${homeAssistantIP}:8889;
    #  }
  '';
  services.nginx.virtualHosts."ha" = {
    serverName = "ha.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://${homeAssistantIP}:8123";
      proxyWebsockets = true;
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
  };

  #virtualisation.oci-containers.backend = "podman";

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    # MQTT
    1883
    # HLS
    # 8888
    # WebRTC
    # 8889
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
  my.common.tailscale.enable = true;

  # Enable DNS server.
  # Serves DNS for the rest of the network.
  my.dns.blocky = {
    enable = true;
    openFirewall = true;
  };
  # Getting an error binding to all interfaces when doing nixos-rebuild switch:
  # ERROR server start failed: start udp listener failed: listen udp :53: bind: address already in use
  # This seems to be due to dnsmasq running due to libvirtd.
  #
  # Possible solutions:
  # - Disable dnsmasq - probably VMs on this host could do without DHCP
  # - Bind only to certain interfaces - seems to be causing problems
  #   with the systemd service not starting at boot - worked around by
  #   setting blocky service to always restart itself.
  #
  # Bind to localhost, main IP address, and Tailscale IP address.
  # This doesn't seem reliable; sometimes can't bind to the main IP address
  # at boot (see also https://systemd.io/NETWORK_ONLINE/), but this is worked
  # around by having the service restart itself.
  services.blocky.settings.ports = {
    dns = "127.0.0.1:53,${myIP}:53,${myTailscaleIP}:53";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
