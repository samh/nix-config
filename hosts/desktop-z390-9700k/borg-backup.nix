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
            "/samh"
            # User configuration
            "/home/samh/.config"
            "/home/samh/.ssh"
            # /root may contain secrets we would like to save.
            "/root"
            # contains uid/gid mappings; might be useful to keep
            # permissions consistent
            "/var/lib/nixos"
            # Service data (StateDirectory) when DynamicUser=true
            "/var/lib/private"
            "/var/lib/tailscale"
          ];
          # https://borgbackup.readthedocs.io/en/stable/usage/help.html#borg-help-patterns
          exclude_patterns = [
            # Path full-match, selector pf: (very fast)
            "pf:/samh/Documents/Notes/Notes-Crypt"
            "pf:/samh/Downloads"
            "pf:/samh/opt/jetbrains-toolbox"
            "pf:/root/.ssh/id_ed25519" # be paranoid and don't include this private key
            # Shell-style patterns, selector sh:
            "sh:**/venv/"
            "sh:**/.venv/"
            "*.pyc"
            "/home/*/.cache"
            "**/[Cc]ache*"
            #/samh/src/decode-config
            # Programs that store too-big stuff under .config
            "/home/samh/.config/Code" # stores cache here 🤮
            "/home/samh/.config/vivaldi-backup"
            "/home/samh/.config/syncthing*"
            # Chromium profile junk
            "/home/samh/.config/chromium/hyphen-data"
            "/home/samh/.config/chromium/OnDeviceHeadSuggestModel"
            "/home/samh/.config/chromium/**/*Cache"
            # Firefox profile junk
            "**/datareporting"
            "**/safebrowsing"
          ];
          repositories = [
            "/media/backup/borg-pc"
            "ssh://o7tw4si1@o7tw4si1.repo.borgbase.com/./repo"
          ];
        };
        hooks = {
          healthchecks = "\${HEALTHCHECKS_URL:-empty}";
        };
      };
  };
}
