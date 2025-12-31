{
  config,
  lib,
  pkgs,
  ...
}: {
  # NVIDIA GeForce RTX 2070 SUPER
  # https://wiki.nixos.org/wiki/NVIDIA
  # On desktop, I don't want this to be used for the desktop, because I want
  # to be able to unbind it for use in a VM.
  # See also vfio-host.nix.

  services.xserver.videoDrivers = [
    # Use Intel ("modesetting") driver first.
    "modesetting"
    # Load NVIDIA driver.
    # Not sure if we need this for just using CUDA.
    #"nvidia"
  ];

  hardware.graphics.enable = true;
  hardware.nvidia = {
    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;
    open = true; # Set to false for proprietary drivers
  };

  hardware.nvidia-container-toolkit.enable = config.virtualisation.podman.enable;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];

  my.allowedUnfree = [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
  ];
}
