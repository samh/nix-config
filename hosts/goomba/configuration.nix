# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
{
  inputs,
  outputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../include/common.nix

    # Import home-manager's NixOS module (i.e. build home-manager profile
    # at the same time as the system configuration with nixos-rebuild)
    inputs.home-manager.nixosModules.home-manager

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

  networking.hostName = "goomba"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  environment.systemPackages = with pkgs; [
    dua # Disk Usage Analyzer (ncdu alternative)
    git # required for building flakes
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # Disable sudo password
  security.sudo.wheelNeedsPassword = false;

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    users = {
      # Import your home-manager configuration
      samh = import ../../home-manager/goomba.nix;
    };
  };

  # List services that you want to enable:

  # nginx for reverse proxy
  #  my.nginx = {
  #    enable = true;
  #    openFirewall = true;
  #  };

  networking.firewall.allowedTCPPorts = [
    # Stirling PDF
    8080
  ];

  virtualisation.oci-containers.backend = "podman";

  # In rootful mode, podman uses subuid mappings for 'containers'
  # when using '--userns=auto'.
  # See https://docs.podman.io/en/latest/markdown/podman-run.1.html#userns-mode
  # For a start, I'm using the start and count values from the podman-run
  # documentation.
  users.users.containers = {
    # 'containers' doesn't really need to be a user, but I don't see a
    # good way to add subuid/subgid mappings in NixOS without making it a user.
    isSystemUser = true;
    group = "containers";
    subUidRanges = [
      {
        startUid = 2147483647;
        count = 2147483648;
      }
    ];
    subGidRanges = [
      {
        startGid = 2147483647;
        count = 2147483648;
      }
    ];
  };
  users.groups.containers = {};

  # Enable automatic updates (based on image tags) for containers running
  # under systemd.
  # https://docs.podman.io/en/latest/markdown/podman-auto-update.1.html
  systemd.timers."podman-auto-update" = {
    wantedBy = ["multi-user.target"];
    # Default is daily with 900 second RandomizedDelay.
    # See https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html
    # timerConfig = {
    #   OnCalendar=daily;
    # };
  };

  virtualisation.oci-containers.containers = {
    stirling-pdf = {
      # I don't really care which version of this image is used;
      # latest is fine.
      image = "docker.io/frooodle/s-pdf:latest";
      labels = {
        "io.containers.autoupdate" = "registry";
      };
      # Normally I would want it to listen only on localhost, then forward via
      # reverse proxy. For this testing, it will just be exposed directly.
      #ports = ["127.0.0.1:8080:8080"];
      ports = ["8080:8080"];
      volumes = [
        "/var/lib/stirling-pdf/configs:/configs:U"
      ];
      environment = {
        # No login authentication required for now
        DOCKER_ENABLE_SECURITY = "false";
        INSTALL_BOOK_AND_ADVANCED_HTML_OPS = "false";
        LANGS = "en_US";
      };
      # "podman run" options
      extraOptions = [
        "--userns=auto"
      ];
    };
  };
  # Create config directory for stirling-pdf
  systemd.tmpfiles.rules = [
    "d /var/lib/stirling-pdf/configs 0770 - wheel"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
