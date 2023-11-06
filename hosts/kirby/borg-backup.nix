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
        storage.encryption_passcommand = "${pkgs.coreutils}/bin/cat /root/borg-pass-general";
        location = {
          source_directories = [
            "/root"
            # /var/lib/nixos contains uid/gid mappings; might be useful to keep
            # permissions consistent
            "/var/lib/nixos"
            # Service data
            "/var/lib/paperless"
            # Service data (StateDirectory) when DynamicUser=true,
            # for example for 'uptime-kuma'
            "/var/lib/private"
            "/var/lib/tailscale"
            # Home Assistant backups
            "/srv/shares/homeassistant-backup"
          ];
          repositories = ["ssh://f66k66p2@f66k66p2.repo.borgbase.com/./repo"];
        };
        hooks = {
          # Note: since borgmatic is running as root, I created a "root" user
          # in the database who can read all databases; it's using the default
          # peer authentication. See README.md.
          postgresql_databases = [
            {
              # "all" to dump all databases on the host.
              name = "all";
              # dumps each database to a separate file in "custom" format
              format = "custom";
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
          healthchecks = "\${HEALTHCHECKS_URL:-empty}";
        };
      };
  };

  # Add environment file to borgmatic service, to pass HEALTHCHECKS_URL
  #  systemd.services.borgmatic.serviceConfig.EnvironmentFile = "/root/borgmatic.env";

  # Add packages to borgmatic service PATH.
  # PostgreSQL is needed for the postgresql_databases hook.
  # TODO: is it possible to add to the path of the "borgmatic" wrapper script,
  #       so it works when running that directly?
  systemd.services.borgmatic.path = [
    config.services.postgresql.package
  ];
}
