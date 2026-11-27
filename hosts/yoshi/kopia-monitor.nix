{
  config,
  lib,
  pkgs,
  ...
}: let
  requiredPaths = [
    ''C:\Users\kayeh\Documents''
  ];

  check = pkgs.writeShellScript "check-mom-backups" ''
    set -euo pipefail

    snapshots=$(
      /run/current-system/sw/bin/kopia-family \
        snapshot list --all --json --show-identical
    )

    if printf '%s' "$snapshots" | ${pkgs.jq}/bin/jq -e \
      --arg host "windows-lsk72q6" \
      --arg user "kayeh" \
      --argjson paths ${lib.escapeShellArg (builtins.toJSON requiredPaths)} '
        def timestamp:
          sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601;

        . as $snapshots |
        now as $now |
        all($paths[];
          . as $path |
          any($snapshots[];
            .source.host == $host and
            .source.userName == $user and
            .source.path == $path and
            ((.incompleteReason // "") == "") and
            ((.stats.errorCount // 1) == 0) and
            ((.stats.ignoredErrorCount // 0) == 0) and
            ((.rootEntry.summ.numFailed // 0) == 0) and
            (
              (try (.endTime | timestamp) catch 0) as $end |
              $end >= ($now - 48 * 3600) and
              $end <= ($now + 300)
            )
          )
        )
      ' >/dev/null
    then
      suffix=""
      result=0
      message="All required folders have a clean backup within 48 hours."
    else
      suffix="/fail"
      result=1
      message="A required folder has no clean backup within 48 hours."
    fi

    echo "$message"
    ping_url=$(cat "$CREDENTIALS_DIRECTORY/healthchecks-url")

    ${pkgs.curl}/bin/curl \
      --fail --silent --show-error \
      --connect-timeout 10 --max-time 30 --retry 2 \
      --data-raw "$message" \
      "$ping_url$suffix"

    exit "$result"
  '';
in {
  sops.secrets.kopia-mom-healthchecks-url = {};

  systemd.services.kopia-mom-monitor = {
    description = "Check freshness of Mom's Kopia backups";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    unitConfig.RequiresMountsFor = ["/srv/kopia"];
    unitConfig.ConditionPathIsMountPoint = "/srv/kopia";

    serviceConfig = {
      Type = "oneshot";
      User = "kopia";
      Group = "kopia";
      Environment = "HOME=/var/lib/kopia-family";
      LoadCredential = [
        "healthchecks-url:${config.sops.secrets.kopia-mom-healthchecks-url.path}"
      ];
      ExecStart = check;
      TimeoutStartSec = "10min";
    };
  };

  systemd.timers.kopia-mom-monitor = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 09:00:00";
      Persistent = true;
    };
  };
}
