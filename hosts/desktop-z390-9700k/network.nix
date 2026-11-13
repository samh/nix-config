# Desktop Ethernet configuration using NetworkManager.
#
# Interfaces:
#   eno2             - onboard 1 GbE, backup
#   enusb0           - USB 2.5 GbE, preferred (6c:1f:f7:1b:f1:d6)
#   enusb1           - USB 2.5 GbE, alternate (6c:1f:f7:17:11:48)
#
# All three physical NICs are members of the active-backup bond named bond0.
# Only one link carries traffic at a time. USB adapters take priority over the
# onboard interface; either adapter can be used in any USB port.
#
# bond0 uses eno2's existing MAC address, b4:2e:99:35:58:90. This preserves the
# DHCP identity associated with the OPNsense reservation for 192.168.5.32. The
# physical interfaces do not obtain their own IP addresses.
{...}: {
  # udev applies these names independently of NetworkManager. Match permanent
  # addresses because joining the bond changes a member's current MAC address.
  systemd.network.links = {
    "10-bond-usb0" = {
      matchConfig.PermanentMACAddress = "6c:1f:f7:1b:f1:d6";
      linkConfig = {
        NamePolicy = "";
        Name = "enusb0";
      };
    };
    "10-bond-usb1" = {
      matchConfig.PermanentMACAddress = "6c:1f:f7:17:11:48";
      linkConfig = {
        NamePolicy = "";
        Name = "enusb1";
      };
    };
  };

  networking.networkmanager = {
    enable = true;

    # Do not create new automatic Ethernet profiles for the bond members.
    # Existing persistent profiles must be removed once when deploying this
    # configuration so that they cannot compete with the bond profiles.
    settings.main.no-auto-default = "b4:2e:99:35:58:90,6c:1f:f7:1b:f1:d6,6c:1f:f7:17:11:48";

    ensureProfiles.profiles = {
      # Logical bonded interface. DHCP runs only on this interface.
      bond0 = {
        connection = {
          id = "bond0";
          type = "bond";
          interface-name = "bond0";
          autoconnect = true;
          autoconnect-ports = 1;
        };

        # Bond options are a dictionary. In a NetworkManager keyfile, each
        # dictionary entry is emitted directly as a key in the [bond] section.
        bond = {
          mode = "active-backup";
          miimon = 100;
          primary = "enusb0";
        };

        ethernet.cloned-mac-address = "b4:2e:99:35:58:90";

        ipv4 = {
          method = "auto";
          dhcp-client-id = "mac";
        };

        ipv6.method = "auto";
      };

      # Preferred USB 2.5 GbE bond member.
      bond-usb = {
        connection = {
          id = "bond-usb";
          type = "ethernet";
          interface-name = "enusb0";
          controller = "bond0";
          port-type = "bond";
          autoconnect = true;
        };

        ethernet.mac-address = "6c:1f:f7:1b:f1:d6";
        bond-port.prio = 200;
      };

      # Alternate USB adapter, preferred over onboard Ethernet during failover.
      bond-usb-alt = {
        connection = {
          id = "bond-usb-alt";
          type = "ethernet";
          interface-name = "enusb1";
          controller = "bond0";
          port-type = "bond";
          autoconnect = true;
        };

        ethernet.mac-address = "6c:1f:f7:17:11:48";
        bond-port.prio = 100;
      };

      # Backup onboard GbE bond member.
      bond-onboard = {
        connection = {
          id = "bond-onboard";
          type = "ethernet";
          interface-name = "eno2";
          controller = "bond0";
          port-type = "bond";
          autoconnect = true;
        };

        ethernet.mac-address = "b4:2e:99:35:58:90";
      };
    };
  };
}
