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
      config.local.borg.borgmatic-defaults
      {
        storage.encryption_passcommand = "${pkgs.coreutils}/bin/cat /root/borg-pass-general";
        location = {
          source_directories = [
            "/root"
            # contains uid/gid mappings; might be useful to keep
            # permissions consistent
            "/var/lib/nixos"
            # Service data (StateDirectory) when DynamicUser=true,
            # for example for 'uptime-kuma'
            "/var/lib/private"
            "/var/lib/tailscale"
          ];
          repositories = ["ssh://f66k66p2@f66k66p2.repo.borgbase.com/./repo"];
        };
        hooks = {
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
}
