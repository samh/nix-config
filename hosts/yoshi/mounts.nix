{
  config,
  pkgs,
  ...
}: {
  services.btrfs.autoScrub.enable = true;
  services.btrfs.autoScrub.interval = "monthly";
  # Make sure not to list duplicates (i.e. multiple mount points that
  # point to the same underlying volume)!
  services.btrfs.autoScrub.fileSystems = [
    "/pool/ssd-root" # /
    "/pool/16TB.2023.3GPN" # 16 TB WD Red Pro (2023)
  ];

  # Storage (HDD)
  #
  # The "nofail" option tells systemd to mount them asynchronously, instead
  # of waiting until they are mounted to continue, making the boot a little
  # faster.
  #
  # Disks backing mergerfs pool
  fileSystems."/media/disk3" = {
    device = "LABEL=16TB-2023-3GPN";
    fsType = "btrfs";
    options = ["nofail" "subvol=@disk3" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."media/disk4.4TB.raid1" = {
    device = "LABEL=disk4.4TB.raid1";
    fsType = "btrfs";
    options = ["nofail" "subvol=@disk4" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };

  # Mergerfs pool
  fileSystems."/storage" = {
    device = "/media/disk*";
    fsType = "fuse.mergerfs";
    # ignorepponrename=true - reduces path preservation, but that can
    #   probably be corrected after the fact if I care.
    # Author recommended that create=mspmfs or just mfs is
    # "generally what people are looking for" when they enable
    # ignorepponrename.
    options = [
      "defaults"
      "nonempty"
      "allow_other"
      "use_ino"
      "moveonenospc=true"
      "category.create=mspmfs"
      "ignorepponrename=true"
      "dropcacheonclose=true"
      "minfreespace=250G"
      "fsname=mergerfs"
      # "x-systemd.device-timeout=0" # causes dmesg errors on mergerfs
    ];
  };

  # Root pools for btrbk backups
  fileSystems."/pool/ssd-root" = {
    device = "LABEL=nixos";
    fsType = "btrfs";
    options = ["compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/pool/16TB.2023.3GPN" = {
    device = "LABEL=16TB-2023-3GPN";
    fsType = "btrfs";
    options = ["nofail" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/pool/disk4.4TB.raid1" = {
    device = "LABEL=disk4.4TB.raid1";
    fsType = "btrfs";
    options = ["nofail" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
}
