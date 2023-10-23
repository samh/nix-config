{
  config,
  pkgs,
  ...
}: {
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/6c999188-02a8-42e2-a70d-175464e9e7c2";
    fsType = "btrfs";
    options = ["subvol=@" "compress=zstd:9"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/BD29-809C";
    fsType = "vfat";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/5f3cfe03-1887-4ac5-92cb-e5bfaa4062fd";}
  ];

  # Root pools for btrbk backups and general management.
  # Also, /pool mounts are automatically enabled for autoScrub in common.nix.
  fileSystems."/pool/root" = {
    device = "/dev/disk/by-uuid/6c999188-02a8-42e2-a70d-175464e9e7c2";
    fsType = "btrfs";
    options = ["compress=zstd:9"];
  };
}
