{
  config,
  lib,
  pkgs,
  ...
}: let
  printer_ip = "192.168.107.90";
  allowed_ranges = "192.168.4. 192.168.5. ${printer_ip}";
  scanner_user = "scanner";
  scanner_group = "inbox";
  scanner_share_dir = "/srv/shares/scanner";

  ha_backup_share_dir = "/srv/shares/homeassistant-backup";
  ha_ip = config.my.metadata.vms.homeassistant.internal_ip;
in {
  # Add scanner user and group
  users.groups.${scanner_group} = {
    gid = 20000;
  };
  users.users.${scanner_user} = {
    uid = 20010;
    isNormalUser = false;
    isSystemUser = true;
    group = "${scanner_group}";
    extraGroups = ["${scanner_group}"];
    home = "/var/empty";
    createHome = false;
    shell = "/sbin/nologin";
  };
  # Also allow my user to access the scanner share directory
  users.users."${config.my.user}".extraGroups = ["${scanner_group}"];

  # Add user and group for Home Assistant
  users.groups.homeassistant = {
    gid = 20020;
  };
  users.users.homeassistant = {
    uid = 20020;
    isNormalUser = false;
    isSystemUser = true;
    group = "homeassistant";
    extraGroups = ["homeassistant"];
    home = "/var/empty";
    createHome = false;
    shell = "/sbin/nologin";
  };

  # Create the share directories
  # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html
  systemd.tmpfiles.rules = [
    # This is disabled because it is being added to tmpfiles by
    # the paperless module because it's set as consumptionDir.
    # v = create btrfs subvolume if possible
    #"v ${scanner_share_dir} 0770 ${scanner_user} ${scanner_group}"

    # For Home Assistant backups, clean up old backups using the
    # age field.
    # "cm" indicates that it should check creation and modification
    # times but not access time.
    "v ${ha_backup_share_dir} 0750 homeassistant homeassistant cm:1d"
  ];

  services.samba = {
    enable = true;
    openFirewall = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = ${config.networking.hostName}
      netbios name = ${config.networking.hostName}
      security = user
      #use sendfile = yes
      #max protocol = smb2
      guest account = nobody
      map to guest = bad user

      # Don't load printers
      load printers = no
      printing = bsd
      printcap name = /dev/null
      disable spoolss = yes
    '';
    shares = {
      # Samba for scanner
      scanner = {
        "path" = "${scanner_share_dir}";
        "public" = "no";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "hosts allow" = "${allowed_ranges} 127.0.0.1 ::1";
        "hosts deny" = "0.0.0.0/0";
        # Allow group to write, so that paperless
        # can clean up processed files.
        "create mode" = "0664";
        "force create mode" = "0664";
        "create mask" = "0644";
        "directory mode" = "0775";
        "force directory mode" = "0775";
        "directory mask" = "0775";
        "write list" = "@${scanner_group}";
        "force user" = "${scanner_user}";
        "force group" = "${scanner_group}";
      };

      # Samba share for Home Assisant backups
      #
      # Configured in Home Assistant at
      # https://my.home-assistant.io/redirect/storage/
      homeassistant-backup = {
        "path" = "${ha_backup_share_dir}";
        "public" = "no";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "hosts allow" = "${ha_ip}";
        "hosts deny" = "0.0.0.0/0";
        "create mode" = "0644";
        "force create mode" = "0644";
        "create mask" = "0644";
        "directory mode" = "0755";
        "force directory mode" = "0755";
        "directory mask" = "0755";
        "write list" = "@homeassistant";
        "force user" = "homeassistant";
        "force group" = "homeassistant";
      };
    };
  };
}
