{
  config,
  pkgs,
  ...
}: let
  btrfs_opts = ["compress=zstd:9" "x-systemd.device-timeout=0"];
in {
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3170-BA05";
    fsType = "vfat";
  };

  # New btrfs filesystem outside of LVM
  boot.initrd.luks.devices."luks-fwnixos2".device = "/dev/disk/by-uuid/4adcdfb4-3f3f-49de-a1ca-ea5807aca8d6";
  fileSystems."/home" = {
    device = "/dev/mapper/luks-fwnixos2";
    fsType = "btrfs";
    options = ["subvol=@home-nixos" "compress=zstd:9"];
  };
  fileSystems."/home-fedora" = {
    device = "/dev/mapper/luks-fwnixos2";
    fsType = "btrfs";
    options = ["subvol=@home-fedora" "compress=zstd:9"];
  };
  fileSystems."/" = {
    device = "/dev/mapper/luks-fwnixos2";
    fsType = "btrfs";
    options = ["subvol=@" "compress=zstd:9"];
  };
  fileSystems."/tmp" = {
    device = "/dev/mapper/luks-fwnixos2";
    fsType = "btrfs";
    options = ["subvol=@tmp" "compress=zstd:9"];
  };
  fileSystems."/var/lib/flatpak" = {
    device = "/dev/mapper/luks-fwnixos2";
    fsType = "btrfs";
    options = ["subvol=@flatpak-nixos" "compress=zstd:9"];
  };
  # Separate partition because directory is marked No_COW
  fileSystems."/var/lib/libvirt/images" = {
    device = "/dev/mapper/luks-fwnixos2";
    fsType = "btrfs";
    options = ["subvol=@libvirt-images" "compress=zstd:9"];
  };

  # Root pool(s) for btrbk backups and general management.
  # Also, /pool mounts are automatically enabled for autoScrub in common.nix.
  # (but auto-scrub is disabled on laptop for now)
  fileSystems."/pool/luks-fwnixos2" = {
    device = "/dev/mapper/luks-fwnixos2";
    fsType = "btrfs";
    options = btrfs_opts;
  };
}
