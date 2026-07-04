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

  # The Intel iGPU drives the host display. Use Xorg's built-in modesetting
  # driver; the legacy xf86-video-intel driver fails to load on 26.05, and
  # listing "nvidia" here makes Xorg try to use the GPU that VFIO owns.
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

  # Do not generate NVIDIA CDI devices at boot. The GPU is normally bound to
  # vfio-pci, so nvidia-ctk/NVML probes just fail and load NVIDIA modules.
  #
  # Tradeoff: host-side NVIDIA containers will not work from a cold boot with
  # the stock CDI setup. For those, first unbind the GPU from vfio-pci, bind it
  # to the NVIDIA driver, then run a one-shot CDI generation/restart as part of
  # that workflow. Re-enabling this option globally favors host containers over
  # the normal VM passthrough path and can recreate the boot-time probe failures.
  hardware.nvidia-container-toolkit.enable = false;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia

    # Keep NVIDIA userspace tools available for manual bind/unbind workflows.
    # nvidia-cdi-generator needs nvidia-smi and related binaries to generate a
    # non-empty CDI spec after the card has been rebound to the NVIDIA driver.
    # Do not add "nvidia" to services.xserver.videoDrivers just to get these
    # tools; that makes the display manager try to use the VFIO-owned card.
    config.hardware.nvidia.package.bin
  ];

  my.allowedUnfree = [
    "nvidia-x11"
    "nvidia-settings"
    "nvidia-persistenced"
  ];
}
