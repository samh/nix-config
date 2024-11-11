{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.borg;
in {
  options.my.borg = {
    # Default options for borgmatic, that can be merged into borgmatic
    # configurations as needed.
    # Unfortunately this doesn't allow for using the configuration name
    # e.g. as part of the passcommand. Maybe we can use a function instead?
    #
    # Note '//' doesn't recursively merge, though 'lib.recursiveUpdate'
    # does. This should be less of a problem as of NixOS 23.11, since
    # borgmatic is updated to the version that uses flat configuration
    # (e.g. 'storage.encryption_passcommand' is now just
    # 'encryption_passcommand').
    borgmatic-defaults = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        encryption_passcommand = "${pkgs.coreutils}/bin/cat /root/borg-pass";
        compression = "auto,zstd,9";
        keep_within = "24H";
        keep_daily = 7;
        keep_weekly = 4;
        keep_monthly = 6;
        keep_yearly = 5;
      };
    };

    common-exclude-patterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # Path full-match, selector pf: (very fast)
        "pf:/root/.ssh/id_ed25519" # be paranoid and don't include this private key
        # Shell-style patterns, selector sh:
        "sh:**/venv/"
        "sh:**/.venv/"
        "*.pyc"
        "/home/*/.cache"
        "**/[Cc]ache*"
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
    };
  };

  config = {
    # Add SSH public keys for Borgbase
    #
    # This key appears to be used by all the US servers I've seen, but note
    # that the EU servers are different.
    programs.ssh.knownHosts = {
      "*.repo.borgbase.com" = {
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGU0mISTyHBw9tBs6SuhSq8tvNM8m9eifQxM+88TowPO";
      };
    };

    services.borgmatic.enable = lib.mkDefault true;
    # Add environment file to borgmatic service, to pass HEALTHCHECKS_URL
    systemd.services.borgmatic.serviceConfig.EnvironmentFile = lib.mkDefault "/root/borgmatic.env";
  };
}
