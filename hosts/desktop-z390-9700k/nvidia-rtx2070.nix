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

  # Force the desktop stack to use the iGPU.
  services.xserver.videoDrivers = ["modesetting"];

  hardware.graphics.enable = true;

  # Ensure the NVIDIA *kernel modules* are included in the system closure so
  # `modprobe nvidia` works after unbinding from vfio-pci.
  boot.extraModulePackages = lib.mkAfter [config.hardware.nvidia.package.passthru.open];

  hardware.nvidia = {
    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;
    open = true; # Set to false for proprietary drivers
  };

  hardware.nvidia-container-toolkit = {
    enable = config.virtualisation.podman.enable;
    suppressNvidiaDriverAssertion = true;
  };

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];

  my.allowedUnfree = [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
  ];
}
