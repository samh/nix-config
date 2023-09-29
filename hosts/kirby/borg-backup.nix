{
  config,
  pkgs,
  ...
}: {
  # Add SSH public keys for Borgbase
  programs.ssh.knownHosts = {
    "*.repo.borgbase.com" = {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGU0mISTyHBw9tBs6SuhSq8tvNM8m9eifQxM+88TowPO";
    };
  };

  # Add Borgmatic configurations
  services.borgmatic.enable = true;
  services.borgmatic.configurations = let
    mkBorgmaticConfig = name: {
      storage = {
        # NOTE: need to deploy password file somehow
        encryption_passcommand = "${pkgs.coreutils}/bin/cat /root/borg-pass-${name}";
        compression = "auto,zstd,9";
      };
      retention = {
        keep_within = "24H";
        keep_daily = 7;
        keep_weekly = 4;
        keep_monthly = 6;
        keep_yearly = 5;
      };
    };
  in {
    "general" =
      mkBorgmaticConfig "general"
      // {
        location = {
          source_directories = [
            "/var/lib/private/uptime-kuma"
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
  systemd.services.borgmatic.serviceConfig.EnvironmentFile = "/root/borgmatic.env";
}
