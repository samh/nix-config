{
  config,
  pkgs,
  ...
}: let
  btrfs_opts = ["compress=zstd:9"];
in {
  fileSystems."/home" = {
    device = "LABEL=gaming-home";
    fsType = "btrfs";
    options = ["subvol=@home"] ++ btrfs_opts;
  };
  fileSystems."/games" = {
    device = "LABEL=games-nvme2";
    fsType = "btrfs";
    options = ["subvol=@games"] ++ btrfs_opts;
  };
  fileSystems."/games-hdd" = {
    device = "LABEL=game-2";
    fsType = "btrfs";
    options = ["subvol=@games"] ++ btrfs_opts;
  };

  # Root pools for btrbk backups and general management.
  # Also, /pool mounts are automatically enabled for autoScrub in common.nix.
  fileSystems."/pool/home" = {
    device = "LABEL=gaming-home";
    fsType = "btrfs";
    options = btrfs_opts;
  };
  fileSystems."/pool/games-nvme2" = {
    device = "LABEL=games-nvme2";
    fsType = "btrfs";
    options = btrfs_opts;
  };
  fileSystems."/pool/games-hdd" = {
    device = "LABEL=game-2";
    fsType = "btrfs";
    options = btrfs_opts;
  };
}
