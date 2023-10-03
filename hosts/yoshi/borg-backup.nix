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
        location = {
          source_directories = [
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
          ];
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
  };
}
