{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.local.common;
in {
  options.local.borg = {
    # Default options for borgmatic, that can be merged into borgmatic
    # configurations as needed.
    # Unfortunately this doesn't allow for using the configuration name
    # e.g. as part of the passcommand. Maybe we can use a function instead?
    #
    # Note '//' doesn't recursively merge, so if you want to
    # e.g. override 'storage.encryption_passcommand' you lose the default
    # 'storage.compression' setting; seems like 'lib.recursiveUpdate'
    # works better for this case.
    # In general it should be less of a problem once borgmatic is updated
    # to the version that uses flatter configuration.
    borgmatic-defaults = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
        storage = {
          encryption_passcommand = "${pkgs.coreutils}/bin/cat /root/borg-pass";
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
    };
  };

  config = {
    # Add SSH public keys for Borgbase
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
