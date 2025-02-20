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
        devices = ["fwnixos" "yoshi"]; # Which devices to share the folder with
        versioning = defaultVersioning;
      };
      "Notes-Shared" = {
        id = "evgke-fvs53";
        enable = true;
        path = "${config.my.homeDir}/Notes/Notes-Shared";
        devices = [
          "vfio-windows"
          "yoshi"
          "fwnixos"
          "work-laptop"
          "pixel8"
        ];
        versioning = defaultVersioning;
      };
      "Notes-Personal" = {
        id = "jjbsv-stmrg";
        enable = true;
        path = "${config.my.homeDir}/Notes/Notes-Personal";
        devices = ["vfio-windows" "yoshi" "fwnixos" "pixel4a" "pixel8"];
        versioning = defaultVersioning;
      };
      # Calibre work library (technical reference material, including
      # e.g. books, manuals, quick reference cards)
      "Calibre-Work" = {
        id = "nqtzd-2klbn";
        enable = true;
        path = "/samh/Calibre-Work";
        devices = [
          "yoshi"
          "work-laptop"
        ];
        versioning = {
          type = "staggered";
          params = {
            cleanInterval = "3600";
            maxAge = "1000";
          };
        };
      };
      # Shared folder with work. Replaced Onedrive shared folder Work-ACS-Share
      # when that stopped syncing and became a link that opened a browser.
      "Sync-Work-ACS-Share" = {
        id = "294m6-yjmjw";
        enable = true;
        path = "/samh/Sync-Work-ACS-Share";
        devices = ["work-laptop" "yoshi"];
        versioning = defaultVersioning;
      };
    };
  };
}
