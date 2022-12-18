{ config, pkgs, ... }:

{
  fileSystems."/home" =
    { device = "/dev/nvme2/home";
      fsType = "btrfs";
      options = [ "subvol=@home-nixos" "compress=zstd:9" ];
    };
  fileSystems."/samh" =
    { device = "/dev/nvme2/home";
      fsType = "btrfs";
      options = [ "subvol=@home-common" "compress=zstd:9" ];
    };
  fileSystems."/var/lib/flatpak" =
    { device = "/dev/nvme2/flatpak";
      fsType = "btrfs";
      options = [ "subvol=@flatpak-nixos" "compress=zstd:15" ];
    };

#  fileSystems."/media/fedora2020" =
#    { device = "/dev/nvme/fedora2020";
#      fsType = "btrfs";
#      options = [ "subvol=kderoot" "compress=zstd:9" ];
#    };

  fileSystems."/media/vm1" =
    { device = "/dev/nvme/vm1";
      fsType = "ext4";
      options = [ "x-systemd.device-timeout=0" ];
    };

  # libvirt qemu configuration; on Ubuntu and Fedora this is /etc/libvirt/qemu
  fileSystems."/var/lib/libvirt/qemu" =
    { device = "/dev/nvme2/home";
      fsType = "btrfs";
      options = [ "subvol=@qemu-nixos" "compress=zstd:9" ];
    };

  # Storage (HDD)
  #
  # The "nofail" option tells systemd to mount them asynchronously, instead
  # of waiting until they are mounted to continue, making the boot a little
  # faster.
  fileSystems."/media/data1" =
    { device = "/dev/storage/data1";
      fsType = "btrfs";
      options = [ "nofail" "subvol=@main" "compress=zstd:9" "x-systemd.device-timeout=0" ];
    };
  fileSystems."/media/temp1" =
    { device = "/dev/storage/temp1";
      fsType = "ext4";
      options = [ "nofail" "noatime" "x-systemd.device-timeout=0" ];
    };
  fileSystems."/media/backup" =
    { device = "/dev/storage/backup";
      fsType = "btrfs";
      options = [ "nofail" "noatime" "compress=zstd:9" "x-systemd.device-timeout=0" ];
    };
  fileSystems."/media/vm2-hdd" =
    { device = "/dev/storage/vm2-hdd";
      fsType = "ext4";
      options = [ "nofail" "noatime" "x-systemd.device-timeout=0" ];
    };

  # Root pools for btrbk backups
  fileSystems."/pool/nvme-nixos" =
    { device = "/dev/mapper/nvme-nixos";
      fsType = "btrfs";
      options = [ "compress=zstd:9" "x-systemd.device-timeout=0" ];
    };
  fileSystems."/pool/nvme-samh" =
    { device = "/dev/nvme/samh";
      fsType = "btrfs";
      options = [ "compress=zstd:9" "x-systemd.device-timeout=0" ];
    };
  fileSystems."/pool/nvme2-home" =
    { device = "/dev/nvme2/home";
      fsType = "btrfs";
      options = [ "compress=zstd:9" "x-systemd.device-timeout=0" ];
    };
#  fileSystems."/pool/fedora2020" =
#    { device = "/dev/nvme/nvme-fedora2020";
#      fsType = "btrfs";
#      options = [ "compress=zstd:9" "x-systemd.device-timeout=0" ];
#    };
}
