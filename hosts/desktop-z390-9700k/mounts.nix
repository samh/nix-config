{
  config,
  pkgs,
  ...
}: let
  # this line prevents hanging on network split
  net_automount_opts = [
    "x-systemd.after=network-online.target"
    "x-systemd.automount"
    "noauto"
    "_netdev"
    "x-systemd.idle-timeout=60"
    "x-systemd.device-timeout=5s"
    "x-systemd.mount-timeout=5s"
  ];
  samba_permission_opts = [
    "uid=${toString config.users.users.${config.my.user}.uid}"
    "file_mode=0660"
    "dir_mode=0770"
  ];
in {
  # Scrub for pools is in common.nix. This adds to that list.
  services.btrfs.autoScrub.fileSystems = [
    "/var/lib/flatpak"
    "/media/backup"
  ];

  fileSystems."/home" = {
    device = "/dev/nvme2/home";
    fsType = "btrfs";
    options = ["subvol=@home-nixos" "compress=zstd:9"];
  };
  fileSystems."/samh" = {
    device = "/dev/nvme2/home";
    fsType = "btrfs";
    options = ["subvol=@home-common" "compress=zstd:9"];
  };
  # FHS: "/srv contains site-specific data which is served by this system."
  # "This main purpose of specifying this is so that users may find the
  # location of the data files for a particular service"
  fileSystems."/srv" = {
    device = "/dev/nvme2/home";
    fsType = "btrfs";
    options = ["subvol=@srv" "compress=zstd:9"];
  };

  fileSystems."/var/lib/flatpak" = {
    device = "/dev/nvme2/flatpak";
    fsType = "btrfs";
    options = ["subvol=@flatpak-nixos" "compress=zstd:15"];
  };

  #  fileSystems."/media/fedora2020" =
  #    { device = "/dev/nvme/fedora2020";
  #      fsType = "btrfs";
  #      options = [ "subvol=kderoot" "compress=zstd:9" ];
  #    };

  # AI models etc.
  fileSystems."/media/ai" = {
    device = "/dev/nvme/ai";
    fsType = "btrfs";
    options = [
      "subvol=@ai"
      # Not sure if it makes sense to enable compression; models are not
      # likely to be compressible.
      "compress=zstd:3"
      # Don't mount at boot, in case we want to mount it into a VM.
      "noauto"
    ];
  };

  # VM data stores
  fileSystems."/media/vm1" =
    # VM data on first NVMe drive (1TB)
    {
      device = "/dev/nvme/vm1";
      fsType = "ext4";
      options = ["x-systemd.device-timeout=0"];
    };

  # libvirt qemu configuration; on Ubuntu and Fedora this is /etc/libvirt/qemu
  fileSystems."/var/lib/libvirt/qemu" = {
    device = "/dev/nvme2/home";
    fsType = "btrfs";
    options = ["subvol=@qemu-nixos" "compress=zstd:9"];
  };

  # Storage (HDD)
  #
  # The "nofail" option tells systemd to mount them asynchronously, instead
  # of waiting until they are mounted to continue, making the boot a little
  # faster.
  fileSystems."/media/data1" = {
    device = "/dev/storage/data1";
    fsType = "btrfs";
    options = ["nofail" "subvol=@main" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/media/temp1" = {
    device = "/dev/storage/temp1";
    fsType = "ext4";
    options = ["nofail" "noatime" "x-systemd.device-timeout=0"];
  };
  fileSystems."/media/backup" = {
    device = "/dev/storage/backup";
    fsType = "btrfs";
    options = ["nofail" "noatime" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/media/vm2-hdd" = {
    device = "/dev/storage/vm2-hdd";
    fsType = "ext4";
    options = ["nofail" "noatime" "x-systemd.device-timeout=0"];
  };

  # Remote filesystems
  # https://nixos.wiki/wiki/Samba
  # For mount.cifs, required unless domain name resolution is not needed.
  environment.systemPackages = [pkgs.cifs-utils];
  fileSystems."/mnt/storage" = {
    device = "//yoshi.hartsfield.xyz/storage";
    fsType = "cifs";
    options =
      net_automount_opts
      ++ samba_permission_opts
      ++ [
        "credentials=/root/smb-secrets"
      ];
  };
  # Jellyfin library (writes with "multimedia" group permissions)
  fileSystems."/mnt/Library" = {
    device = "//yoshi.hartsfield.xyz/Library";
    fsType = "cifs";
    options =
      net_automount_opts
      ++ samba_permission_opts
      ++ [
        "credentials=/root/smb-secrets"
        "gid=${toString config.users.groups.multimedia.gid}"
      ];
  };
  # Audiobooks library (writes with "audiobookshelf" group permissions)
  fileSystems."/mnt/AudiobooksLibrary" = {
    device = "//yoshi.hartsfield.xyz/AudiobooksLibrary";
    fsType = "cifs";
    options =
      net_automount_opts
      ++ samba_permission_opts
      ++ [
        "credentials=/root/smb-secrets"
        "gid=${toString config.users.groups.multimedia.gid}"
      ];
  };
  # Add tmpfiles rule to create symbolic link from /storage to /mnt/storage
  systemd.tmpfiles.rules = [
    "L /storage - - - - /mnt/storage"
  ];

  # Root pools for btrbk backups and general management.
  # Also, /pool mounts are automatically enabled for autoScrub in common.nix.
  fileSystems."/pool/nvme-nixos" = {
    device = "/dev/mapper/nvme-nixos";
    fsType = "btrfs";
    options = ["compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/pool/nvme2-home" = {
    device = "/dev/nvme2/home";
    fsType = "btrfs";
    options = ["compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/pool/data1" = {
    device = "/dev/storage/data1";
    fsType = "btrfs";
    options = ["nofail" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  #  fileSystems."/pool/fedora2020" =
  #    { device = "/dev/nvme/nvme-fedora2020";
  #      fsType = "btrfs";
  #      options = [ "compress=zstd:9" "x-systemd.device-timeout=0" ];
  #    };
}
