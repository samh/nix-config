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

    ./gui.nix
    ./mounts.nix

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
  # When this system was installed, it mounted the EFI system partition
  # at /boot/efi. The default now seems to be /boot.
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.efi.canTouchEfiVariables = true;

  #  boot.kernelPackages = pkgs.linuxPackages_zen;
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  networking.hostName = "bowser"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Allow my user for remote builds
  # see https://nixos.wiki/wiki/Nixos-rebuild
  # to fix errors like:
  #   "error: cannot add path '/nix/store/...' because it lacks a signature by a trusted key"
  nix.settings.trusted-users = ["samh"];

  # GUI - disabled for now to increase memory for AI stuff
  my.gui.enable = false;

  # Still need NVIDIA drivers for AI work
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = ["nvidia"];
  hardware.nvidia.open = false; # Set to false for proprietary drivers

  environment.systemPackages = with pkgs; [
    dua # Disk Usage Analyzer (ncdu alternative)
    git # required for building flakes
    pkgs.unstable.gollama # Tool for managing Ollama models - https://github.com/sammcj/gollama/
    # pkgs.unstable.isd # Waiting for it to be added to unstable
    nh # Yet another nix cli helper
    nvtopPackages.nvidia
    uv # Python package tool
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # Allow unfree packages: Steam, etc.
  nixpkgs.config.allowUnfree = true;

  home-manager = {
    extraSpecialArgs = {inherit inputs outputs;};
    users = {
      # Import your home-manager configuration
      samh = import ../../home-manager/${config.networking.hostName}.nix;
    };
  };

  # Define a work user for SSH port forwarding
  users.users.samh-work = {
    uid = 1020;
    isNormalUser = true;
    # Note: stored in /etc/ssh/authorized_keys.d/, not ~/.ssh/authorized_keys
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQTyE9sDcqE6+VAHmIMQ58GWjbcBkB6jrArOCyAgBqJ samh-work-ed25519-2023"
    ];
    shell = pkgs.fish;
  };

  # List services that you want to enable:

  my.common.tailscale.enable = true;
  my.pool.allowWheel = true;

  my.common.podman.enable = true;
  virtualisation.podman.dockerCompat = true;
  hardware.nvidia-container-toolkit.enable = true;

  # LLM framework
  services.ollama = {
    enable = true;
    acceleration = "cuda";
    package = pkgs.unstable.ollama-cuda;
    host = "0.0.0.0";
    environmentVariables = {
      # https://github.com/ollama/ollama/blob/main/docs/faq.md
      # "Flash Attention is a feature of most modern models that can
      # significantly reduce memory usage as the context size grows"
      OLLAMA_FLASH_ATTENTION = "1";
      # "The K/V context cache can be quantized to significantly reduce
      # memory usage when Flash Attention is enabled"
      # "How much the cache quantization impacts the model's response
      # quality will depend on the model and the task. Models that have
      # a high GQA count (e.g. Qwen2) may see a larger impact on
      # precision from quantization than models with a low GQA count."
      # "You may need to experiment with different quantization types
      # to find the best balance between memory usage and quality."
      # Options: f16 (default), q8_0, q4_0
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };
  # Allow ollama over tailscale
  # WARNING: does not have any authentication
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [config.services.ollama.port];
  };

  # LLM web frontend GUI
  services.open-webui = {
    # TODO: CORS_ALLOW_ORIGIN? USER_AGENT?
    enable = true;
    package = pkgs.unstable.open-webui;
    host = "0.0.0.0";
    openFirewall = true;
    environment = {
      # Let everybody access all models
      BYPASS_MODEL_ACCESS_CONTROL = "True";
      # These are apparently the defaults in the NixOS module, but they don't
      # appear to be actual options according to the documentation. Maybe they
      # used to be?
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?
}
