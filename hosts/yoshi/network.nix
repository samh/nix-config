# network.nix
#
# Network configuration for a server with two Ethernet interfaces:
#
#   enp2s0  - SFP+ / DAC, preferred link
#   enp5s0  - built-in GbE, backup link
#
# The interfaces are combined into an active-backup bond named bond0.
# Only one physical interface carries traffic at a time:
#
#   enp2s0 (SFP+)  ----\
#                       +---- bond0 ---- LAN
#   enp5s0 (GbE)   ----/
#
# enp2s0 is marked as the primary interface, so it is normally used whenever
# it has carrier. If it loses link, the bond automatically switches to enp5s0.
# When enp2s0 comes back, PrimaryReselectPolicy=always causes the bond to
# return to it.
#
# IP configuration belongs to bond0, not to either physical interface.
# bond0 obtains its IPv4 address by DHCP.
#
# The bond has a fixed, locally-administered MAC address:
#
#   02:00:00:00:00:40
#
# Configure the DHCP server with a reservation for this MAC. For this host,
# that reservation should assign the desired address ending in .40.
#
# "02" in the first octet marks this as a locally administered unicast MAC,
# so it does not conflict with manufacturer-assigned MAC address space.
{...}: {
  # This host previously used NetworkManager. The server has a fixed network
  # topology, so systemd-networkd is a simpler fit for the bonded interfaces.
  networking = {
    networkmanager.enable = false;

    # Prevent NixOS's traditional DHCP/interface configuration from also
    # managing these interfaces. The complete topology and DHCP configuration
    # are defined directly with systemd.network below.
    useDHCP = false;
  };

  systemd.network = {
    enable = true;

    # Create the virtual bond interface.
    netdevs."10-bond0" = {
      netdevConfig = {
        Name = "bond0";
        Kind = "bond";

        # Give the bond a permanent network identity independent of which
        # physical interface is currently active.
        MACAddress = "02:00:00:00:00:40";
      };

      bondConfig = {
        # Only one member is active at a time. No LACP or special switch
        # configuration is required.
        Mode = "active-backup";

        # Poll physical link/carrier state every 100 ms. This handles failures
        # such as a disconnected DAC, failed NIC, or switch port losing link.
        MIIMonitorSec = "100ms";

        # Prefer the designated primary interface whenever it is available.
        # Thus, after failing over to GbE, the bond switches back to SFP+
        # when the SFP+ link becomes healthy again.
        PrimaryReselectPolicy = "always";
      };
    };

    networks = {
      # Preferred SFP+ interface.
      "20-enp2s0" = {
        matchConfig.Name = "enp2s0";

        networkConfig = {
          Bond = "bond0";

          # Marks this member as the preferred active interface.
          PrimarySlave = true;
        };

        # This interface does not itself need to become "online"; bond0 does.
        linkConfig.RequiredForOnline = "no";
      };

      # Backup built-in GbE interface.
      "20-enp5s0" = {
        matchConfig.Name = "enp5s0";

        networkConfig.Bond = "bond0";

        linkConfig.RequiredForOnline = "no";
      };

      # IP configuration is applied to the bond itself.
      "30-bond0" = {
        matchConfig.Name = "bond0";

        networkConfig = {
          DHCP = "ipv4";
        };

        dhcpV4Config = {
          # Identify the DHCP client using bond0's explicitly configured MAC.
          # This makes a normal MAC-based DHCP reservation straightforward.
          ClientIdentifier = "mac";
        };
      };
    };
  };
}
