{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../include/borg-backup.nix
  ];

  # Create a postgresql user for root to be used by borgmatic to dump all
  # databases.
  services.postgresql.ensureUsers = [
    {
      name = "root";
    }
  ];
  systemd.services.postgresql.postStart = lib.mkAfter ''
    $PSQL postgres -c 'GRANT pg_read_all_data TO "root"'
  '';
  # Add packages to borgmatic service PATH.
  # PostgreSQL is needed for the postgresql_databases hook.
  # TODO: is it possible to add to the path of the "borgmatic" wrapper script,
  #       so it works when running that directly?
  systemd.services.borgmatic.path = [
    config.services.postgresql.package
  ];

  # Add Borgmatic configurations
  services.borgmatic.configurations = {
    "general" =
      config.my.borg.borgmatic-defaults
      // {
        source_directories =
          [
            # /root may contain secrets we would like to save.
            "/root"
            # contains uid/gid mappings; might be useful to keep
            # permissions consistent
            "/var/lib/nixos"

            # App data on HDD - archivebox
            "/data/appdata"

            # Audiobookshelf config and metadata
            "/var/lib/audiobookshelf"
            # Calibre Server (users SQLite database)
            "/var/lib/calibre-server"
            # ErstazTV data
            "/var/lib/ersatztv"
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
        # Note: since borgmatic is running as root, I created a "root" user
        # in the database who can read all databases; it's using the default
        # peer authentication. See the 'ensureUsers' and 'postStart' above.
        postgresql_databases = [
          {
            # "all" to dump all databases on the host.
            name = "all";
            # dumps each database to a separate file in "custom" format
            format = "custom";
          }
        ];
        repositories = [
          {
            label = "borgbase-general";
            path = "ssh://waxs18i4@waxs18i4.repo.borgbase.com/./repo";
          }
        ];
        healthchecks = {ping_url = "\${HEALTHCHECKS_URL:-empty}";};
      };

    "photos" = {
      source_directories = [
        "/storage/Pictures" # ~30G
        "/data/Photos" # device backups - Syncthing ~25G
        "/storage/Backup-Photos" # ~80G
      ];
      one_file_system = false;
      repositories = [
        {
          label = "borgbase-photos";
          path = "ssh://a7a635p6@a7a635p6.repo.borgbase.com/./repo";
        }
      ];
      # Note: this password was originally used on the previous storage server.
      encryption_passcommand = "${pkgs.coreutils}/bin/cat /root/borg-pass-photos";
      compression = "auto,zstd,9";
      keep_within = "24H";
      keep_daily = 7;
      keep_weekly = 4;
      keep_monthly = 6;
      keep_yearly = 1000;
      healthchecks = {ping_url = "\${HEALTHCHECKS_URL_PHOTOS:-empty}";};
    };

    "media" =
      config.my.borg.borgmatic-defaults
      // {
        source_directories = [
          "/storage/Music" # ~60G
          "/storage/Library/Music"
          "/storage/Library/Music-Grace"
          "/storage/Library/Music-Kids"
          "/storage/Books" # ~35G
        ];
        one_file_system = false;
        repositories = [
          {
            label = "borgbase-media-eu";
            path = "ssh://jhbk0u3p@jhbk0u3p.repo.borgbase.com/./repo";
          }
        ];
        keep_yearly = 10;
      };
  };
  programs.ssh.knownHosts = {
    # EU repo - SSH host keys are different.
    "jhbk0u3p.repo.borgbase.com" = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMS3185JdDy7ffnr0nLWqVy8FaAQeVh1QYUSiNpW5ESq";
    };
  };
}
