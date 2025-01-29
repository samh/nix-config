{
  config,
  pkgs,
  ...
}: let
  btrfs_opts = ["compress=zstd:9"];
  # Most of this data will not be compressible.
  btrfs_opts_ai = ["compress=zstd:1"];
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
  fileSystems."/var/lib/private/ollama" = {
    device = "LABEL=ai-data";
    fsType = "btrfs";
    options = ["subvol=@ollama"] ++ btrfs_opts_ai;
  };
  fileSystems."/var/lib/private/open-webui" = {
    device = "LABEL=ai-data";
    fsType = "btrfs";
    options = ["subvol=@open-webui"] ++ btrfs_opts_ai;
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
  fileSystems."/pool/ai" = {
    device = "LABEL=ai-data";
    fsType = "btrfs";
    options = btrfs_opts_ai;
  };
}
