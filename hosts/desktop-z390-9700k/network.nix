# Desktop Ethernet configuration using NetworkManager.
#
# Interfaces:
#   eno2             - onboard 1 GbE, backup
#   enp0s20f0u7u3    - USB 2.5 GbE, preferred
#
# Both physical NICs are members of the active-backup bond named bond0. Only
# one link carries traffic at a time. The USB adapter is preferred whenever it
# is available; traffic falls back to the onboard interface if the USB adapter
# disappears or loses carrier.
#
# bond0 uses eno2's existing MAC address, b4:2e:99:35:58:90. This preserves the
# DHCP identity associated with the OPNsense reservation for 192.168.5.32. The
# physical interfaces do not obtain their own IP addresses.
{...}: {
  networking.networkmanager = {
    enable = true;

    # Do not create new automatic Ethernet profiles for the bond members.
    # Existing persistent profiles must be removed once when deploying this
    # configuration so that they cannot compete with the bond profiles.
    settings.main.no-auto-default = "eno2,enp0s20f0u7u3";

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
          primary = "enp0s20f0u7u3";
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
          interface-name = "enp0s20f0u7u3";
          controller = "bond0";
          port-type = "bond";
          autoconnect = true;
        };

        ethernet.mac-address = "6c:1f:f7:1b:f1:d6";
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
