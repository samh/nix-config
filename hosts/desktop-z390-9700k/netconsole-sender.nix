{pkgs, ...}: let
  localAddress = "192.168.5.32";
  localPort = 6665;
  receiverAddress = "192.168.5.40";
  receiverMac = "02:00:00:00:00:40";
  receiverPort = 6666;
in {
  systemd.services.netconsole-sender = {
    description = "Send kernel messages to Yoshi with netconsole";
    after = ["NetworkManager.service"];
    wants = ["NetworkManager.service"];
    wantedBy = ["multi-user.target"];

    path = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.kmod
    ];

    script = ''
      set -euo pipefail

      for attempt in $(seq 1 30); do
        if ip link show dev bond0 2>/dev/null | grep -Fq "state UP" \
          && ip -4 address show dev bond0 | grep -Fq "inet ${localAddress}/"; then
          break
        fi

        if [ "$attempt" -eq 30 ]; then
          echo "bond0 did not acquire ${localAddress} within 30 seconds" >&2
          exit 1
        fi

        sleep 1
      done

      modprobe netconsole \
        "netconsole=+r${toString localPort}@${localAddress}/bond0,${toString receiverPort}@${receiverAddress}/${receiverMac}"
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.kmod}/bin/modprobe -r netconsole";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
