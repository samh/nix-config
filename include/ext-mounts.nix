{
  config,
  pkgs,
  ...
}: {
  # External HDD mount points
  #
  # NOTE: for these "noauto" mounts, the mount point doesn't get created
  # automatically unless you use the systemd unit to start it.
  # For example:
  #   systemctl list-unit-files | grep mount
  #   systemctl start 'media-ext\x2dretro.mount'
  # Or possibly using systemd-escape:
  #   systemctl start $(systemd-escape -p --suffix=mount /media/ext-retro)
  #

  # Naming conventions WIP:
  # - ext-{CAPACITY}-{YEAR}-{LAST 4 OF SERIAL} e.g. ext-12TB-2019-TAKT
  # - ext-{THING} for specific things?
  # - How about /ext/ instead? Or /media/ext/?
  # - Something other than dashes? They create ugly systemd unit names...

  # External 12TB WD EasyStore
  fileSystems."/ext/12TB.2019.TAKT" = {
    device = "/dev/disk/by-uuid/7a2664f3-753f-42a8-87ab-7f41983ceefe";
    fsType = "btrfs";
    options = ["noauto" "noatime" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  #fileSystems."/media/ext-retro" =
  fileSystems."/ext/retro" = {
    device = "/dev/disk/by-label/12TB-external-1";
    fsType = "btrfs";
    options = ["noauto" "noatime" "subvol=@retro" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
  fileSystems."/media/ext-video" = {
    device = "/dev/disk/by-label/12TB-external-1";
    fsType = "btrfs";
    options = ["noauto" "noatime" "subvol=@video" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };

  # External 14TB WD EasyStore
  fileSystems."/ext/14TB.2021.WUHL" = {
    device = "/dev/disk/by-label/14TB-2021-WUHL";
    fsType = "btrfs";
    options = ["noauto" "noatime" "compress=zstd:9" "x-systemd.device-timeout=0"];
  };
}
