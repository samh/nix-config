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

  hardware.nvidia-container-toolkit = {
    enable = config.virtualisation.podman.enable;
    # The NVIDIA driver is intentionally kept out of services.xserver.videoDrivers
    # because the GPU is normally bound to vfio-pci at boot.
    suppressNvidiaDriverAssertion = true;
  };

  # Keep the NVIDIA container toolkit available, but do not generate CDI devices
  # at boot or when Podman starts. The GPU is normally bound to vfio-pci, so a
  # boot-time nvidia-ctk/NVML probe just fails and loads NVIDIA modules.
  #
  # Host-side NVIDIA containers still need the manual bind/unbind flow: unbind
  # the GPU from vfio-pci, bind it to the NVIDIA driver, then restart this
  # one-shot generator or let the toolkit's udev rule restart it when /dev/nvidia*
  # appears.
  systemd.services.nvidia-container-toolkit-cdi-generator = {
    wantedBy = lib.mkForce [];
    requiredBy = lib.mkForce [];
  };

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
