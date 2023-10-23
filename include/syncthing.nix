# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  ...
}: {
  imports = [
    ./metadata.nix
  ];
  options = {
  };

  config = {
    services.syncthing = {
      enable = true;
      user = "${config.my.user}";
      # Default folder for new synced folders
      dataDir = "${config.my.homeDir}/Documents";
      # Folder for Syncthing's settings and keys
      configDir = "${config.my.homeDir}/.config/syncthing";
      # Whether to open the default ports in the firewall: TCP/UDP 22000 for transfers and UDP 21027 for discovery.
      openDefaultPorts = true;

      overrideDevices = true; # overrides any devices added or deleted through the WebUI
      overrideFolders = true; # overrides any folders added or deleted through the WebUI

      # By default, include all hosts in metadata, which have a syncthing_id,
      # but excluding the current host.
      # Would be nice to also add "addresses" if available (local and tailscale).
      devices =
        builtins.mapAttrs (name: value: {id = value.syncthing_id;})
        # Filter out all the hosts without a syncthing_id,
        # and filter out the current host.
        (lib.filterAttrs (n: v: (v ? syncthing_id) && (n != config.networking.hostName))
          config.my.metadata.hosts);
      folders = {
      };
    };
  };
}
