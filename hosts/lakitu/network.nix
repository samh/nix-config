{config, ...}: {
  # https://nixos.wiki/wiki/Systemd-networkd
  # https://www.freedesktop.org/software/systemd/man/latest/systemd-networkd.service.html
  systemd.network = {
    enable = true;
    # See https://www.freedesktop.org/software/systemd/man/latest/systemd.netdev.html
    netdevs = {
      # Create the bridge interfaces
      "20-br0" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br0";
        };
      };
      "20-br1" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br1";
        };
      };
    };
    # See https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html
    networks = {
      # Connect the bridge ports to the bridge
      "30-enp1s0" = {
        matchConfig.Name = "enp2s0"; # top NIC
        networkConfig.Bridge = "br0";
        linkConfig.RequiredForOnline = "enslaved";
      };
      "30-enp2s0" = {
        matchConfig.Name = "enp5s4"; # bottom NIC
        networkConfig.Bridge = "br1";
        linkConfig.RequiredForOnline = "enslaved";
      };
      # Configure the bridge networks
      "40-br0" = {
        matchConfig.Name = "br0";
        bridgeConfig = {};
        linkConfig = {
          RequiredForOnline = "no";
          ActivationPolicy = "down";
        };
      };
      "40-br1" = {
        matchConfig.Name = "br1";
        networkConfig.DHCP = "ipv4";
        bridgeConfig = {};
        linkConfig = {
          # or "routable" with IP addresses configured
          RequiredForOnline = "carrier";
        };
      };
    };
  };
}
