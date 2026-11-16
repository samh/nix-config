{pkgs, ...}: let
  localAddress = "192.168.5.32";
  localPort = 6665;
  receiverAddress = "192.168.5.40";
  receiverMac = "02:00:00:00:00:40";
  receiverPort = 6666;
in {
  # Netconsole follows the console threshold: include warnings, notices, and
  # informational messages so the remote capture has context before a freeze.
  boot.consoleLogLevel = 7;

  systemd.services.netconsole-sender = {
    description = "Send kernel messages to Yoshi with netconsole";
    after = ["NetworkManager.service" "sys-kernel-config.mount"];
    wants = ["NetworkManager.service"];
    requires = ["sys-kernel-config.mount"];
    wantedBy = ["multi-user.target"];

    path = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.kmod
    ];

    script = ''
      set -euo pipefail

      # A bond releasing its slaves disables the kernel target without failing
      # this service. Monitor configfs rather than trusting a oneshot's status.
      # Use a named dynamic target so recovery does not reload the whole module.
      modprobe netconsole
      target=/sys/kernel/config/netconsole/yoshi
      mkdir -p "$target"
      # New targets start disabled. The kernel rejects a redundant disable
      # with EINVAL, so only disable an existing enabled target.
      if [ "$(cat "$target/enabled")" = 1 ]; then
        echo 0 > "$target/enabled"
      fi
      echo bond0 > "$target/dev_name"
      echo ${localAddress} > "$target/local_ip"
      echo ${toString localPort} > "$target/local_port"
      echo ${receiverAddress} > "$target/remote_ip"
      echo ${toString receiverPort} > "$target/remote_port"
      echo ${receiverMac} > "$target/remote_mac"
      echo 1 > "$target/extended"
      echo 1 > "$target/release"

      while true; do
        if ip link show dev bond0 2>/dev/null | grep -Fq "state UP" \
          && ip -4 address show dev bond0 | grep -Fq "inet ${localAddress}/" \
          && [ "$(cat "$target/enabled")" = 0 ]; then
          # The interface can change between the readiness check and this
          # write. Retry on the next pass rather than abandoning capture.
          if echo 1 > "$target/enabled"; then
            echo "Enabled netconsole target yoshi on bond0"
          else
            echo "Could not enable netconsole target; retrying in 5 seconds" >&2
          fi
        fi
        sleep 5
      done
    '';
    postStop = ''
      # Remove the configfs reference before unloading, including on failure.
      if [ -d /sys/kernel/config/netconsole/yoshi ]; then
        rmdir /sys/kernel/config/netconsole/yoshi
      fi
      modprobe -r netconsole
    '';

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
