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

  # Intel iGPU drives the display, but we still list "nvidia" here so that
  # X11/KDE session environment is configured properly (even though the dGPU
  # is bound to vfio-pci at boot).
  services.xserver.videoDrivers = ["modesetting" "nvidia"];

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

  hardware.nvidia-container-toolkit.enable = config.virtualisation.podman.enable;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia

    # nvidia-cdi-generator needs to find nvidia-smi (and other tools) on the host
    # to generate a non-empty CDI spec.
    # It seems like this would normally be added by adding "nvidia" to
    # services.xserver.videoDrivers, but that is causing the display manager to
    # fail in NixOS 25.11.
    config.hardware.nvidia.package.bin
  ];

  my.allowedUnfree = [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
  ];
}
