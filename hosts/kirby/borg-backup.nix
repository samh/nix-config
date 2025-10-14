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
        encryption_passcommand = "${pkgs.coreutils}/bin/cat /root/borg-pass-general";
        source_directories = [
          "/root"
          "/home/samh/src/ai-stack"
          "/var/lib/forgejo"
          "/var/lib/gitea"
          "/var/lib/karakeep"
          # /var/lib/nixos contains uid/gid mappings; might be useful to keep
          # permissions consistent
          "/var/lib/nixos"
          # Service data
          config.services.forgejo.stateDir
          "/var/lib/open-webui"
          "/var/lib/paperless"
          # Service data (StateDirectory) when DynamicUser=true,
          # Includes: 'blocky', 'uptime-kuma'
          "/var/lib/private"
          "/var/lib/tailscale"
          # Home Assistant backups
          "/srv/shares/homeassistant-backup"
        ];
        repositories = [
          {
            label = "borgbase";
            path = "ssh://f66k66p2@f66k66p2.repo.borgbase.com/./repo";
          }
        ];
        # Note: since borgmatic is running as root, I created a "root" user
        # in the database who can read all databases; it's using the default
        # peer authentication. See the 'ensureUsers' and 'postStart' above.
        postgresql_databases = [
          {
            # NOTE: currently all+custom broken in 25.05; see https://github.com/NixOS/nixpkgs/pull/413251
            # To list databases, run: `sudo -u postgres psql -l`
            # "all" to dump all databases on the host.
            name = "all";
            # dumps each database to a separate file in "custom" format
            # format = "custom";
          }
        ];

        commands = [
          {
            before = "action";
            when = ["create"];
            run = [
              # Stop gitea service before backup to ensure consistent state.
              "${pkgs.systemd}/bin/systemctl stop gitea"
              # Stop forgejo service before backup to ensure consistent state.
              "${pkgs.systemd}/bin/systemctl stop forgejo"
              # Karakeep uses SQLite files.
              # Karakeep - for some reason stopping workers takes a long time.
              "${pkgs.systemd}/bin/systemctl stop karakeep-web.service karakeep-workers.service"
            ];
          }
          {
            after = "action";
            when = ["create"];
            run = [
              # Start services that were stopped before
              "${pkgs.systemd}/bin/systemctl start gitea"
              "${pkgs.systemd}/bin/systemctl start forgejo"
              "${pkgs.systemd}/bin/systemctl start karakeep-web.service karakeep-workers.service"
            ];
          }
        ];

        # Healthchecks ping URL or UUID to notify when a backup
        # begins, ends, or errors. Create an account at
        # https://healthchecks.io if you'd like to use this service.
        # See borgmatic monitoring documentation for details.
        #
        # The URL is a secret, so get it from the EnvironmentFile.
        # Use ":-" to try to make it easier
        # to run commands like "borgmatic list" without sourcing the
        # environment file.
        # I tried making it an empty string, but that gave an error:
        # Healthchecks error: 400 Client Error: Bad Request for url: https://hc-ping.com/$%7BHEALTHCHECKS_URL:-%7D
        # Seems to work if we give it some arbitrary string.
        healthchecks = {ping_url = "\${HEALTHCHECKS_URL:-empty}";};
      };
  };

  # Add environment file to borgmatic service, to pass HEALTHCHECKS_URL
  #  systemd.services.borgmatic.serviceConfig.EnvironmentFile = "/root/borgmatic.env";
}
