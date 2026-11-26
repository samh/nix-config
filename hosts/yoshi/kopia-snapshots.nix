{pkgs, ...}: let
  pool = "/pool/disk4.4TB.raid1";
  snapshotDir = "${pool}/kopia-snapshots";

  btrbkConfig = pkgs.writeText "kopia-snapshots.conf" ''
    timestamp_format long
    snapshot_dir ${snapshotDir}
    snapshot_create always
    snapshot_preserve_min 2d
    snapshot_preserve 14d 8w

    volume ${pool}
      subvolume @kopia
  '';
in {
  systemd.services.kopia-family-snapshots = {
    description = "Protected snapshots of the family Kopia repository";

    unitConfig = {
      RequiresMountsFor = [pool];
      ConditionPathIsMountPoint = pool;
      ConditionPathExists = "${pool}/@kopia/family/kopia.repository.f";
    };

    path = [
      pkgs.btrfs-progs
      pkgs.coreutils
      pkgs.util-linux
    ];

    serviceConfig = {
      Type = "oneshot";
      User = "root";
      UMask = "0077";
    };

    script = ''
      install -d -m 0700 -o root -g root ${snapshotDir}
      ${pkgs.btrbk}/bin/btrbk -c ${btrbkConfig} run
    '';
  };

  systemd.timers.kopia-family-snapshots = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
