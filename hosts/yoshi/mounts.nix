{
  config,
  pkgs,
  ...
}: {
  # Data for e.g. containers
  fileSystems."/data" = {
    device = "LABEL=10TB-WD-SWTP";
    fsType = "btrfs";
    options = ["subvol=@data" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };

  # Storage (HDD)
  #
  # The "nofail" option tells systemd to mount them asynchronously, instead
  # of waiting until they are mounted to continue, making the boot a little
  # faster.
  #
  # Disks backing mergerfs pool
  fileSystems."/media/disk1" = {
    device = "LABEL=4TB-2014-2282";
    fsType = "btrfs";
    options = ["nofail" "subvol=@disk1" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/media/disk2" = {
    device = "LABEL=10TB-WD-SWTP";
    fsType = "btrfs";
    options = ["nofail" "subvol=@disk2" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/media/disk3" = {
    device = "LABEL=16TB-2023-3GPN";
    fsType = "btrfs";
    options = ["nofail" "subvol=@disk3" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/media/disk4.4TB.raid1" = {
    device = "LABEL=disk4.4TB.raid1";
    fsType = "btrfs";
    options = ["nofail" "subvol=@disk4" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };

  # Mergerfs pool
  fileSystems."/storage" = {
    device = "/media/disk*";
    fsType = "fuse.mergerfs";
    # "Checking was requested for "/media/disk*", but it is not a device."
    noCheck = true;
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
      "posix_acl=true"
      # "x-systemd.device-timeout=0" # causes dmesg errors on mergerfs
    ];
  };

  # Network filesystems
  # system.fsPackages = [pkgs.sshfs];
  # Temporarily mount old Storage Server.
  # Left here as an example.
  #  fileSystems."/media/storage.old" = {
  #    device = "samh@192.168.5.45:/storage/";
  #    fsType = "sshfs";
  #    options = [
  #      # Filesystem options
  #      "allow_other" # for non-root access
  #      "_netdev" # this is a network fs
  #      "x-systemd.automount" # mount on demand
  #
  #      # SSH options
  #      "reconnect" # handle connection drops
  #      "ServerAliveInterval=15" # keep connections alive
  #    ];
  #  };

  # Root pools for btrbk backups and general management.
  # Also, /pool mounts are automatically enabled for autoScrub in common.nix.
  fileSystems."/pool/ssd-root" = {
    device = "LABEL=nixos";
    fsType = "btrfs";
    options = ["compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/pool/16TB.2023.3GPN" = {
    # 16 TB WD Red Pro (2023)
    device = "LABEL=16TB-2023-3GPN";
    fsType = "btrfs";
    options = ["nofail" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/pool/disk4.4TB.raid1" = {
    device = "LABEL=disk4.4TB.raid1";
    fsType = "btrfs";
    options = ["nofail" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/pool/10TB.2020.SWTP" = {
    device = "LABEL=10TB-WD-SWTP";
    fsType = "btrfs";
    options = ["nofail" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/pool/4TB.2014.2282" = {
    device = "LABEL=4TB-2014-2282";
    fsType = "btrfs";
    options = ["nofail" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
}
