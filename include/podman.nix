# This file contains the Podman configuration
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.common.podman;
in {
  options = {
    my.common.podman.enable = mkEnableOption "Podman containers";
  };

  config = mkIf cfg.enable {
    virtualisation = {
      docker.enable = lib.mkDefault false;
      podman = {
        enable = true;
        # Create a `docker` alias for podman, to use it as a drop-in replacement
        dockerCompat = lib.mkDefault false;
        # Required for containers under podman-compose to be able to talk to each other.
        defaultNetwork.settings.dns_enabled = lib.mkDefault true;
      };
    };
    environment.systemPackages = with pkgs; [
      # docker-compose works with podman via "podman compose" wrapper
      # (rootless as well as rootful)
      docker-compose
      podman-compose
      #podlet # Generate Quadlet files from command/compose
    ];
    environment.variables = {
      # "The deprecated BoltDB database driver is in use. This driver will be
      #  removed in the upcoming Podman 6.0 release in mid 2026. It is advised
      #  that you migrate to SQLite to avoid issues when this occurs. Set
      #  SUPPRESS_BOLTDB_WARNING environment variable to remove this message."
      #
      # This warning is pointless until migration support is added in a future
      # podman release. See https://github.com/containers/podman/issues/27628
      SUPPRESS_BOLTDB_WARNING = "1";
    };
    # In rootful mode, podman uses subuid mappings for 'containers'
    # when using '--userns=auto'.
    # See https://docs.podman.io/en/latest/markdown/podman-run.1.html#userns-mode
    # In the podman-run documentation, it uses 2147483647 and 2147483648 as the
    # start and count values, respectively. I am trying using more even numbers,
    # to make them easier to understand (e.g. 1000 in the container becomes
    # 2200001000 on the host for the first container; depending on the offset
    # subsequent containers may be less obvious).
    users.users.containers = {
      # 'containers' doesn't really need to be a user, but I don't see a
      # good way to add subuid/subgid mappings in NixOS without making it a user.
      isSystemUser = true;
      group = "containers";
      subUidRanges = [
        {
          startUid = 2200000000;
          count = 1000000000;
        }
      ];
      subGidRanges = [
        {
          startGid = 2200000000;
          count = 1000000000;
        }
      ];
    };
    users.groups.containers = {};
  };
}
