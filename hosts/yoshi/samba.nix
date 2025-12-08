{
  config,
  lib,
  pkgs,
  ...
}: let
  # 100. = Tailscale (allowing all; we still have password auth on top)
  allowed_ranges = "192.168.4. 192.168.5. 100. 127.0.0.1 ::1";
in {
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = config.networking.hostName;
        "netbios name" = config.networking.hostName;
        security = "user";
        #"use sendfile" = "yes";
        #"max protocol" = "smb2";
        "guest account" = "nobody";
        "map to guest" = "bad user";

        # Try to cooperate with other samba server(s) on the network
        #"local master" = "no";
        "domain master" = "no";
        "preferred master" = "no";

        # Don't load printers
        "load printers" = "no";
        "printing" = "bsd";
        "printcap name" = "/dev/null";
        "disable spoolss" = "yes";

        # Unix extensions / permissions
        "unix extensions" = "yes";
        "vfs objects" = "acl_xattr";
        "map acl inherit" = "yes";

        # Don't map DOS attribute to execute bit
        # (should be the default)
        "map archive" = "no";
        "map system" = "no";
        "map hidden" = "no";
        # Stores DOS attributes in xattrs
        "store dos attributes" = "yes";
      };
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
        # create mode and directory mode are synonyms for the "mask"s, so
        # don't set both.
        # When file/directory is created, permissions will be ANDed with the
        # mask then ORed with the "force" mode.
        #"force create mode" = "0664";
        #"force directory mode" = "0775";
        "directory mask" = "0775";
        "write list" = "${config.my.user}";
      };
      # For the Library (Jellyfin media), we want to use the 'multimedia' group.
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
        "create mask" = "0664";
        "directory mask" = "0775";
        "write list" = "${config.my.user}";
        "force group" = "multimedia";
      };
      # For the Audiobooks Library, we want to use the 'audiobookshelf' group.
      AudiobooksLibrary = {
        "path" = "/storage/Audiobooks/Library";
        "public" = "no";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "hosts allow" = "${allowed_ranges}";
        "hosts deny" = "0.0.0.0/0";
        "create mask" = "0664";
        "directory mask" = "0775";
        "write list" = "${config.my.user}";
        "force group" = "audiobookshelf";
      };
      Retro = {
        "path" = "/storage/Games/Retro";
        "public" = "no";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "hosts allow" = "${allowed_ranges}";
        "hosts deny" = "0.0.0.0/0";
        "directory mask" = "0775";
        "create mask" = "0775";
        "write list" = "${config.my.user}";
        #"force group" = "games";
      };
    };
  };
}
