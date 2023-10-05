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
    ../include/ext-mounts.nix
    ../include/xfce.nix
    #../include/virt-manager.nix
    ./borg-backup.nix
    ./mounts.nix
    ./nvidia-660ti.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the grub boot loader (EFI mode)
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.configurationLimit = 25;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "yoshi"; # Define your hostname.
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
    gparted
    intel-gpu-tools # intel_gpu_top for checking Jellyfin transcoding
    lshw
    mergerfs
    mergerfs-tools
    pciutils # lspci
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # List services that you want to enable:

  # Enable vaapi on OS-level for Jellyfin transcoding
  # From https://nixos.wiki/wiki/Jellyfin
  nixpkgs.config.packageOverrides = pkgs: {
    vaapiIntel = pkgs.vaapiIntel.override {enableHybridCodec = true;};
  };
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
      vaapiVdpau
      libvdpau-va-gl
      intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
    ];
  };

  # Jellyfin
  services.jellyfin.enable = true;
  # Bind the library directory to the same place as it was in the container
  # on the old server, because it takes some database editing to change it.
  # The mount is only visible inside the jellyfin service.
  systemd.services.jellyfin.serviceConfig.BindPaths = "/media/storage.old/Library:/data";
  systemd.services.jellyfin.serviceConfig.RequiresMountsFor = "/media/storage.old/Library";
  # https://jellyfin.org/docs/general/networking/index.html
  networking.firewall = lib.mkIf config.services.jellyfin.enable {
    # 8096/tcp is used by default for HTTP traffic. You can change this in the dashboard.
    # 8920/tcp is used by default for HTTPS traffic. You can change this in the dashboard.
    allowedTCPPorts = [8096 8920];
    # 1900/udp is used for service auto-discovery. This is not configurable.
    # (DLNA also uses this port and is required to be in the local subnet.)
    #
    # 7359/udp is also used for auto-discovery. This is not configurable.
    # Allows clients to discover Jellyfin on the local network. A broadcast
    # message to this port with Who is JellyfinServer? will get a JSON
    # response that includes the server address, ID, and name.
    allowedUDPPorts = [1900 7359];
  };

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
  local.common.tailscale.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
