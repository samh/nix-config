# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/260d5382-94b4-44a4-b04e-1e09805f5e8b";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd:9" ];
    };

  boot.initrd.luks.devices."luks-nixos".device = "/dev/disk/by-uuid/b7970812-3216-4e54-b774-1509a46dc4a1";
  boot.initrd.luks.devices."luks-nixos".preLVM = false;

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/3170-BA05";
      fsType = "vfat";
    };

  fileSystems."/var/lib/flatpak" =
    { device = "/dev/disk/by-uuid/336a47e0-b222-4658-b722-7ab66ea743bb";
      fsType = "btrfs";
      options = [ "subvol=@flatpak-nixos" "compress=zstd:15" ];
    };

  boot.initrd.luks.devices."luks-flatpak".device = "/dev/disk/by-uuid/69395a86-6edb-4d46-b85d-488096bf1fb7";
  boot.initrd.luks.devices."luks-flatpak".preLVM = false;

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/198858cf-edf7-4385-a331-70b1dd0e7702";
      fsType = "btrfs";
      options = [ "subvol=@home-nixos" "compress=zstd:9" ];
    };

  fileSystems."/home-fedora" =
    { device = "/dev/disk/by-uuid/198858cf-edf7-4385-a331-70b1dd0e7702";
      fsType = "btrfs";
      options = [ "subvol=@home-fedora" "compress=zstd:9" ];
    };

  boot.initrd.luks.devices."luks-home".device = "/dev/disk/by-uuid/991fc6ac-9b9e-44d0-a37b-c4f4dbeb9a44";
  boot.initrd.luks.devices."luks-home".preLVM = false;

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp166s0.useDHCP = lib.mkDefault true;

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
