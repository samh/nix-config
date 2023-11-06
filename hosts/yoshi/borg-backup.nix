{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../include/borg-backup.nix
  ];

  # Add Borgmatic configurations
  services.borgmatic.configurations = {
    "general" =
      lib.recursiveUpdate
      config.my.borg.borgmatic-defaults
      {
        location = {
          source_directories =
            [
              # /root may contain secrets we would like to save.
              "/root"
              # contains uid/gid mappings; might be useful to keep
              # permissions consistent
              "/var/lib/nixos"
              # Jellyfin database, configuration, logs
              "/var/lib/jellyfin"
              # Service data (StateDirectory) when DynamicUser=true
              "/var/lib/private"
              "/var/lib/tailscale"
            ]
            ++ (
              if config.services.nextcloud.enable
              then [
                "${config.services.nextcloud.datadir}"
              ]
              else []
            );
          # https://borgbackup.readthedocs.io/en/stable/usage/help.html#borg-help-patterns
          # Shell-style patterns, selector sh: (can use "**" for recursive globbing)
          # Path full-match, selector pf: (very fast)
          exclude_patterns = [
            "pf:/root/.ssh/id_ed25519" # be paranoid and don't include this private key
            "**/[Cc]ache*"
          ];
          repositories = [
            "ssh://waxs18i4@waxs18i4.repo.borgbase.com/./repo"
          ];
        };
        hooks = {
          healthchecks = "\${HEALTHCHECKS_URL:-empty}";
        };
      };

    "photos" = {
      location = {
        source_directories = [
          "/storage/Pictures" # ~30G
          "/data/Photos" # device backups - Syncthing ~25G
          "/storage/Backup-Photos" # ~80G
        ];
        one_file_system = false;
        repositories = [
          "ssh://a7a635p6@a7a635p6.repo.borgbase.com/./repo"
        ];
      };
      storage = {
        # Note: this password was originally used on the previous storage server.
        encryption_passcommand = "${pkgs.coreutils}/bin/cat /root/borg-pass-photos";
        compression = "auto,zstd,9";
      };
      retention = {
        keep_within = "24H";
        keep_daily = 7;
        keep_weekly = 4;
        keep_monthly = 6;
        keep_yearly = 1000;
      };
      hooks = {
        healthchecks = "\${HEALTHCHECKS_URL_PHOTOS:-empty}";
      };
    };
  };
}
