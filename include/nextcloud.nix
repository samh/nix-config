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

      # Redis wants overcommit_memory to be set to 1
      # See https://redis.io/docs/get-started/faq/
      boot.kernel.sysctl."vm.overcommit_memory" = 1;

      services.nextcloud = {
        enable = true;
        hostName = "nextcloud.${config.my.hostDomain}";

        # Use HTTPS for links
        https = true;

        # Need to manually increment with every major upgrade.
        package = pkgs.nextcloud27;

        # Let NixOS install and configure the database automatically.
        # Uses the database type specified by config.dbtype.
        database.createLocally = true;

        # Let NixOS install and configure Redis caching automatically.
        configureRedis = true;

        # Increase the maximum file upload size to avoid problems uploading videos.
        maxUploadSize = "16G";
        # Make sure legacy stuff is disabled
        enableBrokenCiphersForSSE = false;

        # Auto-update Nextcloud Apps
        autoUpdateApps.enable = true;
        # Set what time makes sense for you
        autoUpdateApps.startAt = "05:00:00";

        config = {
          # Further forces Nextcloud to use HTTPS
          overwriteProtocol = "https";

          # Nextcloud PostegreSQL database configuration, recommended over using SQLite
          dbtype = "pgsql";

          adminpassFile = "/var/nextcloud-admin-pass";
          adminuser = "admin";
        };
      };
    })
  ];
}
