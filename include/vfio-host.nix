{ config, pkgs, ... }:

# VFIO configuration.
# See https://forum.level1techs.com/t/nixos-vfio-pcie-passthrough/130916
{
  imports = [
    ./virt-manager.nix
  ];

  boot.kernelParams = [ "intel_iommu=on" ];

  # One of the issues of vfio passthrough is the graphic drivers loading onto
  # the card before we can attach the vfio-pci driver, to prevent this we can
  # set a modules blacklist in our configuration.
  boot.blacklistedKernelModules = [ "nvidia" "nouveau" ];
  # For AMD guest GPU
  #boot.blacklistedKernelModules = [ "amdgpu" "radeon" ];

  # Extra kernel modules required for VFIO
  boot.kernelModules = [ "vfio_virqfd" "vfio_pci" "vfio_iommu_type1" "vfio" ];

  # Attach the video card to the vfio-pci driver
  # This should be the PCI ids of your GPU and GPU sound card
  boot.extraModprobeConfig = "options vfio-pci ids=10de:1e84,10de:10f8,10de:1ad8,10de:1ad9";
}