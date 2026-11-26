{
  config,
  pkgs,
  ...
}: let
  stateDir = "/var/lib/kopia-family";
  pool = "/pool/disk4.4TB.raid1";
  repoDir = "${pool}/@kopia/family";

  # Administrative CLI:
  # sudo -u kopia kopia-family <command>
  admin = pkgs.writeShellScriptBin "kopia-family" ''
    set -euo pipefail
    export HOME=${stateDir}
    export KOPIA_PASSWORD="$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.kopia-family-password.path})"

    exec ${pkgs.kopia}/bin/kopia \
      --config-file=${stateDir}/repository.config \
      "$@"
  '';
in {
  sops.secrets.kopia-family-password = {
    owner = "kopia";
    group = "kopia";
    mode = "0400";
    restartUnits = ["kopia-family.service"];
  };

  users.groups.kopia = {};
  users.users.kopia = {
    isSystemUser = true;
    group = "kopia";
    home = stateDir;
  };

  environment.systemPackages = [
    pkgs.kopia
    pkgs.openssl
    admin
  ];

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 kopia kopia -"
    # Allow traversal of /pool
    "a+ /pool - - - - u:kopia:--x,m::--x"
  ];

  # Tailscale ACLs separately restrict which devices may connect.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [51515];

  systemd.services.kopia-family = {
    description = "Family Kopia repository server";
    wantedBy = ["multi-user.target"];
    wants = ["tailscaled.service"];
    after = ["tailscaled.service"];

    unitConfig = {
      RequiresMountsFor = [pool];
      ConditionPathIsMountPoint = pool;

      # Create this marker only after repository, ACL, and TLS setup.
      ConditionPathExists = "${stateDir}/ready";

      # Keep retrying if the Tailscale address is initially unavailable.
      StartLimitIntervalSec = 0;
    };

    serviceConfig = {
      User = "kopia";
      Group = "kopia";
      UMask = "0077";
      WorkingDirectory = stateDir;

      ExecStart = ''
        ${admin}/bin/kopia-family server start \
          --address=100.64.5.40:51515 \
          --tls-cert-file=${stateDir}/server.crt \
          --tls-key-file=${stateDir}/server.key \
          --no-ui \
          --no-control-api
      '';

      Restart = "on-failure";
      RestartSec = "15s";

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [stateDir repoDir];
    };
  };

  systemd.services.kopia-family-maintenance = {
    description = "Full maintenance of family Kopia repository";

    unitConfig = {
      RequiresMountsFor = [pool];
      ConditionPathIsMountPoint = pool;
      ConditionPathExists = "${stateDir}/ready";
    };

    serviceConfig = {
      Type = "oneshot";
      User = "kopia";
      Group = "kopia";
      UMask = "0077";
      WorkingDirectory = stateDir;
      ExecStart = "${admin}/bin/kopia-family maintenance run --full";

      # Prefer other workloads when CPU or disk access is contested.
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
    };
  };

  systemd.timers.kopia-family-maintenance = {
    description = "Nightly family Kopia maintenance";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";

      # Don't run a missed overnight job during a daytime boot.
      Persistent = false;
    };
  };
}
