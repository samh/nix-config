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

  # Try to resolve timeout on nixos-rebuild switch:
  # "warning: the following units failed: systemd-networkd-wait-online.service"
  # Consider the network online when any interface is online, as opposed to
  # all of them.
  systemd.network.wait-online.anyInterface = true;

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
      "30-br2" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br2";
        };
      };
      # Create VLANs
      "20-vlan107" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan107";
        };
        vlanConfig = {
          Id = 107;
        };
      };
      "20-vlan108" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan108";
        };
        vlanConfig = {
          Id = 108;
        };
      };
    };
    # See https://www.freedesktop.org/software/systemd/man/latest/systemd.network.html
    networks = {
      # Connect the bridge ports to the bridge
      "30-enp4s0" = {
        matchConfig.Name = "enp4s0"; # 2.5Gb card - left port
        networkConfig.Bridge = "br2";
        linkConfig.RequiredForOnline = "enslaved";
      };
      "30-enp5s0" = {
        matchConfig.Name = "enp5s0"; # 2.5Gb card - right port
        networkConfig.Bridge = "br1";
        linkConfig.RequiredForOnline = "enslaved";
      };
      "30-eno1" = {
        matchConfig.Name = "eno1"; # built-in 1Gb NIC
        networkConfig.Bridge = "br0"; # WAN
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
        networkConfig = {
          DHCP = "no";
          LinkLocalAddressing = "no";
        };
      };
      # br1 is the LAN side.
      # Configure it so the host can get an IP address from the router VM.
      "40-br1" = {
        matchConfig.Name = "br1";
        networkConfig = {
          DHCP = "ipv4";
          VLAN = [
            "vlan107"
            "vlan108"
          ];
        };
        bridgeConfig = {};
        linkConfig = {
          # or "routable" with IP addresses configured
          RequiredForOnline = "carrier";
        };
      };
      # 2nd LAN
      "40-br2" = {
        matchConfig.Name = "br2";
        bridgeConfig = {};
        linkConfig = {
          RequiredForOnline = "carrier";
        };
        networkConfig = {
          DHCP = "no";
          LinkLocalAddressing = "no";
        };
      };
      # VLANs
      "50-vlan107" = {
        matchConfig.Name = "vlan107";
        # Static IP
        networkConfig = {
          Address = "192.168.107.2/24";
        };
      };
      "50-vlan108" = {
        matchConfig.Name = "vlan108";
        # Static IP
        networkConfig = {
          Address = "192.168.108.2/24";
        };
      };
    };
  };
}
