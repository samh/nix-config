# NICs:
# eno1 - built-in 1Gb
# enp4s0 - 2.5Gb left/bottom port
# enp5s0 - 2.5Gb right/top port
#
{config, ...}: {
  # Disable other network management services. We are explicitly configuring
  # systemd-networkd below.
  networking.useDHCP = false;
  networking.useNetworkd = false;
  networking.networkmanager.enable = false;

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
      "30-enp4s0" = {
        matchConfig.Name = "enp4s0"; # left port
        networkConfig.Bridge = "br0";
        linkConfig.RequiredForOnline = "enslaved";
      };
      "30-enp5s0" = {
        matchConfig.Name = "enp5s0"; # right port
        networkConfig.Bridge = "br1";
        linkConfig.RequiredForOnline = "enslaved";
      };
      # Configure the bridge networks
      # br0 is the WAN side. Host should not have an IP, but the interface
      # needs to be "up" for a VM to get its WAN IP.
      "40-br0" = {
        matchConfig.Name = "br0";
        bridgeConfig = {};
        linkConfig = {
          RequiredForOnline = "carrier";
        };
      };
      # br1 is the LAN side.
      # Configure it so the host can get an IP address from the router VM.
      "40-br1" = {
        matchConfig.Name = "br1";
        networkConfig.DHCP = "ipv4";
        bridgeConfig = {};
        linkConfig = {
          # or "routable" with IP addresses configured
          RequiredForOnline = "carrier";
        };
      };
      # Configure the built-in NIC (currently as a backup for administration,
      # at least while doing the initial setup)
      "50-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig.DHCP = "ipv4";
        linkConfig = {
          RequiredForOnline = "no";
        };
      };
    };
  };
}
