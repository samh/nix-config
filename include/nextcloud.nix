{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.nextcloud;
in {
  options = {
    my.nextcloud = {
      enable = lib.mkEnableOption "Enable Nextcloud";
    };
    my.nextcloud.office = {
      enable = lib.mkEnableOption "Enable Collabora Online for Nextcloud";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.nginx.virtualHosts = {
        # The name of the virtual host must match the hostName attribute of the
        # Nextcloud service, because that is what the nixpkgs nextcloud.nix
        # configures.
        "${config.services.nextcloud.hostName}" = {
          serverName = config.services.nextcloud.hostName;
          forceSSL = true;
          # Reuse host's wildcard certificate
          useACMEHost = config.my.hostDomain;
        };
      };

      # Set a known UID and GID for the Nextcloud user and group.
      # I initially added this to be able to create the admin password file
      # before enabling Nextcloud, but it seems useful to keep these IDs
      # stable in general.
      users.users.nextcloud.uid = config.my.metadata.uids.nextcloud;
      users.groups.nextcloud.gid = config.my.metadata.gids.nextcloud;

      # Create the share directories
      # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html
      systemd.tmpfiles.rules = [
        # v = create btrfs subvolume if possible
        "v ${config.services.nextcloud.datadir} 0750 nextcloud nextcloud"
      ];

      services.nextcloud = {
        enable = true;
        hostName = "nextcloud.${config.my.hostDomain}";

        # Use HTTPS for links
        https = true;

        # Need to manually increment with every major upgrade.
        package = pkgs.nextcloud30;

        # Let NixOS install and configure the database automatically.
        # Uses the database type specified by config.dbtype.
        database.createLocally = true;

        # Let NixOS install and configure Redis caching automatically.
        configureRedis = true;

        # Increase the maximum file upload size to avoid problems uploading videos.
        maxUploadSize = "16G";

        # Auto-update Nextcloud Apps
        autoUpdateApps.enable = true;
        # Set what time makes sense for you
        autoUpdateApps.startAt = "05:00:00";

        extraAppsEnable = true;
        extraApps = with config.services.nextcloud.package.packages.apps; {
          # List of apps we want to install and are already packaged in
          # https://github.com/NixOS/nixpkgs/blob/master/pkgs/servers/nextcloud/packages/nextcloud-apps.json
          inherit
            calendar
            contacts
            cookbook
            groupfolders
            # memories # photos - to try; see website for setup https://apps.nextcloud.com/apps/memories
            # news # RSS reader - https://apps.nextcloud.com/apps/news
            notes
            # onlyoffice
            # phonetrack # GPS tracking - https://apps.nextcloud.com/apps/phonetrack
            richdocuments # Collabora Online for Nextcloud - https://apps.nextcloud.com/apps/richdocuments

            # spreed # Nextcloud Talk - chat, video, audio conferencing - https://github.com/nextcloud/spreed
            tasks
            #qownnotesapi
            ;
        };

        settings = {
          # Further forces Nextcloud to use HTTPS
          overwriteprotocol = "https";

          # This is required to validate phone numbers in the profile settings without a country code.
          default_phone_region = "US";

          # Start of 4-hour maintenance window, specified as hour UTC
          maintenance_window_start = 6;
        };

        config = {
          # Nextcloud PostegreSQL database configuration, recommended over using SQLite
          dbtype = "pgsql";

          adminpassFile = "/var/nextcloud-admin-pass";
          adminuser = "admin";
        };
        # Suggested by Nextcloud's health check.
        phpOptions."opcache.interned_strings_buffer" = "16";
      };
    })
    (lib.mkIf cfg.office.enable {
      services.collabora-online = {
        enable = true;
        port = 9980;
        settings = {
          # Rely on reverse proxy for SSL
          ssl = {
            enable = false;
            termination = true;
          };
        };
      };
      services.nginx.virtualHosts."collabora" = {
        serverName = "collabora.${config.my.hostDomain}";
        locations."/" = {
          proxyPass = "http://localhost:${toString config.services.collabora-online.port}";
          proxyWebsockets = true;
        };
        forceSSL = true;
        useACMEHost = config.my.hostDomain;
      };
    })
  ];
}
