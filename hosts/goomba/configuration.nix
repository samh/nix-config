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

    pkgs.unstable.podlet
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
    # ArchiveBox
    8000
  ];

  virtualisation.oci-containers.backend = "podman";

  # In rootful mode, podman uses subuid mappings for 'containers'
  # when using '--userns=auto'.
  # See https://docs.podman.io/en/latest/markdown/podman-run.1.html#userns-mode
  # In the podman-run documentation, it uses 2147483647 and 2147483648 as the
  # start and count values, respectively. I am trying using more even numbers,
  # to make them easier to understand (e.g. 1000 in the container becomes
  # 2200001000 on the host for the first container; depending on the offset
  # subsequent containers may be less obvious).
  users.users.containers = {
    # 'containers' doesn't really need to be a user, but I don't see a
    # good way to add subuid/subgid mappings in NixOS without making it a user.
    isSystemUser = true;
    group = "containers";
    subUidRanges = [
      {
        startUid = 2200000000;
        count = 2000000000;
      }
    ];
    subGidRanges = [
      {
        startGid = 2200000000;
        count = 2000000000;
      }
    ];
  };
  users.groups.containers = {};

  # Is it safe to add to /etc/subuid and /etc/subgid directly?
  # *Not really.* It seems to work, but it overwrites the existing
  # entries (e.g. values for normal users that were automatically
  # added).
  #  environment.etc."subuid".text = ''
  #    containers:2200000000:2000000000
  #  '';
  #  environment.etc."subgid".text = ''
  #    containers:2200000000:2000000000
  #  '';

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
      # latest is fine. This will allow it to be updated automatically
      # by the podman-auto-update timer.
      image = "docker.io/frooodle/s-pdf:latest";
      labels = {
        "io.containers.autoupdate" = "registry";
      };
      # Normally I would want it to listen only on localhost, then forward via
      # reverse proxy. For this testing, it will just be exposed directly.
      #ports = ["127.0.0.1:8080:8080"];
      ports = ["8080:8080"];
      volumes = [
        # ":U" will recursively chown the directory to the UID and GID
        # in the container.
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

    # Requires manual setup for the first run. I think the typical NixOS
    # thing to do might be to create a "PreExec" script that checks whether
    # the data directory is empty, and if so, runs the archivebox init command.
    #
    # Initial Setup:
    # mkdir /var/lib/archivebox
    # podman run --userns=auto -v /var/lib/archivebox:/data:U -it docker.io/archivebox/archivebox init --setup
    archivebox = {
      image = "docker.io/archivebox/archivebox:latest";
      # Not sure yet how to manage the permissions to get this container to work.
      # :U recursively chown the directory, but it is to root inside the container.
      # (archivebox refuses to run with PUID=0).
      # Seems like there should be a nicer way to handle this. I'm not clear on all
      # the details of userns=auto yet; the mappings might not always be the same.
      # Maybe manually do the mappings to something static?
      autoStart = false;
      labels = {
        "io.containers.autoupdate" = "registry";
      };
      ports = ["8000:8000"];
      volumes = [
        "/var/lib/archivebox:/data:U"
      ];
      environment = {
        ALLOWED_HOSTS = "*";
      };
      extraOptions = [
        "--userns=auto"
      ];
    };
  }; # virtualisation.oci-containers.containers

  # Try adding Quadlet files
  # Options are documented here:
  # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
  environment.etc."containers/systemd/it-tools.container".text = ''
    [Unit]
    Description=IT Tools Container
    Wants=network-online.target
    After=network-online.target

    [Container]
    Image=docker.io/corentinth/it-tools:latest
    AutoUpdate=registry
    UserNS=auto
    PublishPort=8081:80

    [Install]
    WantedBy=multi-user.target default.target
  '';

  # Create config directories for the services
  systemd.tmpfiles.rules = [
    "d /var/lib/stirling-pdf/configs 0770 - wheel"
    "d /var/lib/archivebox 0770 - wheel"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
