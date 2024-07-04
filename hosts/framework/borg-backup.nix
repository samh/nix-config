{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../include/borg-backup.nix
  ];

  # Add Borgmatic configurations
  services.borgmatic.configurations = {
    "general" =
      config.my.borg.borgmatic-defaults
      // {
        source_directories = [
          # User configuration
          "/home/samh/.config"
          "/home/samh/.ssh"
          # Various documents and files
          "/home/samh/Documents"
          "/home/samh/Notes"
          "/home/samh/Pictures"
          "/home/samh/projects"
          "/home/samh/Sync"
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
        exclude_patterns =
          config.my.borg.common-exclude-patterns
          ++ [
            # Add any local patterns here
          ];
        repositories = [
          {
            label = "borgbase";
            path = "ssh://uqb2iv48@uqb2iv48.repo.borgbase.com/./repo";
          }
        ];
        #healthchecks = {ping_url = "\${HEALTHCHECKS_URL:-empty}";};
      };
  };
}
