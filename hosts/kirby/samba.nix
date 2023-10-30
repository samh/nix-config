{
  config,
  lib,
  pkgs,
  ...
}: let
  printer_ip = "192.168.107.192";
  allowed_ranges = "192.168.4. 192.168.5. ${printer_ip}";
  scanner_user = "scanner";
  scanner_group = "inbox";
  scanner_share_dir = "/srv/shares/scanner";
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

  # Create the share directory
  systemd.tmpfiles.rules = [
    "d ${scanner_share_dir} 0750 ${scanner_user} ${scanner_group}"
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
      # note: localhost is the ipv6 localhost ::1
      hosts allow = ${allowed_ranges} 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
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
        path = "${scanner_share_dir}";
        public = "no";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mode" = "0644";
        "force create mode" = "0644";
        "create mask" = "0644";
        "directory mode" = "0755";
        "force directory mode" = "0755";
        "directory mask" = "0755";
        "write list" = "+${scanner_group}";
        "force user" = "${scanner_user}";
        "force group" = "${scanner_group}";
      };
    };
  };
}
