{
  config,
  pkgs,
  ...
}: let
  listenPort = 6666;
  senderAddress = "192.168.5.32";
in {
  assertions = [
    {
      assertion = config.networking.firewall.backend == "iptables";
      message = "The source-restricted netconsole rule currently requires the iptables firewall backend.";
    }
  ];

  # Netconsole is unauthenticated UDP, so expose the receiver only to the
  # desktop's fixed LAN address. extraCommands is inserted before the final
  # reject rule in NixOS's iptables-based nixos-fw chain.
  networking.firewall.extraCommands = ''
    iptables -w -A nixos-fw \
      -i bond0 \
      -s ${senderAddress}/32 \
      -p udp \
      --dport ${toString listenPort} \
      -j nixos-fw-accept
  '';

  # Keep one receiver process attached to the UDP socket. A socket-activated
  # `cat` would handle only one datagram per service invocation and could hit
  # systemd's start limit during a burst of kernel messages.
  #
  # Output is retained by Yoshi's persistent, size-bounded systemd journal and
  # is queryable with:
  #
  #   journalctl -t netconsole-nixos-2022-desktop
  systemd.services.netconsole-receiver = {
    description = "Receive netconsole messages from nixos-2022-desktop";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.socat}/bin/socat -u UDP-RECV:${toString listenPort},reuseaddr STDOUT";
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "netconsole-nixos-2022-desktop";
      Restart = "on-failure";
      RestartSec = "1s";

      DynamicUser = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RestrictAddressFamilies = ["AF_UNIX" "AF_INET"];
    };
  };
}
