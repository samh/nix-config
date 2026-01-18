{
  config,
  lib,
  pkgs,
  ...
}:
# VFIO configuration.
# See:
# - https://forum.level1techs.com/t/nixos-vfio-pcie-passthrough/130916
# - https://alexbakker.me/post/nixos-pci-passthrough-qemu-vfio.html - also
#   tells how to set up Looking Glass and Scream.
{
  imports = [
    ./virt-manager.nix
  ];

  boot.kernelParams = [
    "intel_iommu=on"
    # "The `pt` option only enables IOMMU for devices used in passthrough and
    # will provide better host performance. However, the option may not be
    # supported on all hardware."
    "iommu=pt"
    # Unclear if this is actually needed, but it could prevent VM crashes
    # in some cases.
    # https://patchwork.kernel.org/project/kvm/patch/1250686963-8357-38-git-send-email-avi@redhat.com/
    "kvm.ignore_msrs=1"
    # kernel complains that "running KVM with isngore_msrs=1 and
    # report_ignored_msrs=0 is not a supported configuration"
    #"kvm.report_ignored_msrs=0"
  ];

  # One of the issues of vfio passthrough is the graphic drivers loading onto
  # the card before we can attach the vfio-pci driver, to prevent this we can
  # set a modules blacklist in our configuration.
  boot.blacklistedKernelModules = [
    #"nvidia"
    "nouveau"
  ];
  # For AMD guest GPU
  #boot.blacklistedKernelModules = [ "amdgpu" "radeon" ];

  # Extra kernel modules required for VFIO
  boot.kernelModules = ["vfio_pci" "vfio_iommu_type1" "vfio"];

  # Load vfio-pci early so it can claim the GPU before other drivers.
  boot.initrd.kernelModules = lib.mkAfter [
    "vfio"
    "vfio_iommu_type1"
    "vfio_pci"
  ];

  # Attach the video card to the vfio-pci driver
  # This should be the PCI ids of your GPU and GPU sound card
  boot.extraModprobeConfig = "options vfio-pci ids=10de:1e84,10de:10f8,10de:1ad8,10de:1ad9";
}
