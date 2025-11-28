# This file defines the Syncthing configuration for one host.
{
  config,
  lib,
  ...
}: let
  defaultVersioning = {
    type = "staggered";
    params = {
      cleanInterval = "3600";
      maxAge = "365"; # Syncthing doc says days; is Nix version the same?
      # versionsPath = ".stversions";
    };
  };
in {
  imports = [
    ../include/syncthing.nix
  ];
  services.syncthing.settings = {
    folders = {
      "Sync-Linux" = {
        # Name of folder in Syncthing, also the folder ID
        id = "Sync-Linux";
        enable = true;
        path = "${config.my.homeDir}/Sync"; # Which folder to add to Syncthing
        devices = ["nixos-2022-desktop" "yoshi"]; # Which devices to share the folder with
        versioning = defaultVersioning;
      };
      "Notes-Shared" = {
        id = "evgke-fvs53";
        enable = true;
        path = "${config.my.homeDir}/Notes/Notes-Shared";
        devices = ["nixos-2022-desktop" "pixel8" "work-laptop" "yoshi"];
        versioning = defaultVersioning;
      };
      "Notes-Personal" = {
        id = "jjbsv-stmrg";
        enable = true;
        path = "${config.my.homeDir}/Notes/Notes-Personal";
        devices = ["nixos-2022-desktop" "pixel8" "yoshi"];
        versioning = defaultVersioning;
      };
      "GameSync" = {
        id = "vq7fn-ijrih";
        enable = true;
        path = "${config.my.homeDir}/Games/Sync";
        devices = ["fwdesktop-cachy" "steamdeck"];
        versioning = {
          type = "staggered";
          params = {
            cleanInterval = "3600";
            maxAge = "30";
          };
        };
      };
      # Shared folder with work. Replaced Onedrive shared folder Work-ACS-Share
      # when that stopped syncing and became a link that opened a browser.
      "Sync-Work-ACS-Share" = {
        id = "294m6-yjmjw";
        enable = true;
        path = "${config.my.homeDir}/Sync-Work-ACS-Share";
        devices = ["work-laptop" "yoshi"];
        versioning = defaultVersioning;
      };
    };
  };
}
