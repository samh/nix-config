{
  config,
  lib,
  pkgs,
  ...
}: let
  allowed_ranges = "192.168.4. 192.168.5. 127.0.0.1 ::1";
in {
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

      # Try to cooperate with other samba server(s) on the network
      #local master = no
      domain master = no
      preferred master = no

      # Don't load printers
      load printers = no
      printing = bsd
      printcap name = /dev/null
      disable spoolss = yes
    '';
    shares = {
      # Samba for /storage (mergerfs).
      # Maybe it would be better to create shares for subdirectories,
      # based on what permissions/groups are needed?
      storage = {
        "path" = "/storage";
        "public" = "no";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "hosts allow" = "${allowed_ranges}";
        "hosts deny" = "0.0.0.0/0";
        "create mode" = "0644";
        #"force create mode" = "0664";
        "create mask" = "0644";
        "directory mode" = "0755";
        #"force directory mode" = "0775";
        "directory mask" = "0775";
        "write list" = "${config.my.user}";
      };
      # For the Library (Jellyfin media), we want to use the multimedia group.
      # Directories should be group-writable; I'm not sure if files need to
      # be.
      Library = {
        "path" = "/storage/Library";
        "public" = "no";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "hosts allow" = "${allowed_ranges}";
        "hosts deny" = "0.0.0.0/0";
        "create mode" = "0664";
        "create mask" = "0664";
        "directory mode" = "0775";
        "directory mask" = "0775";
        "write list" = "${config.my.user}";
        "force group" = "multimedia";
      };
    };
  };
}
