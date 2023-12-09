# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  ...
}: let
  defaultVersioning = {
    type = "staggered";
    params = {
      cleanInterval = "3600";
      maxAge = "1000"; # Syncthing doc says days; is Nix version the same?
      # versionsPath = ".stversions";
    };
  };
  photoVersioning = {
    type = "staggered";
    params = {
      cleanInterval = "3600";
      maxAge = "0"; # Don't delete old photos, ever
    };
  };
in {
  imports = [
    ../include/syncthing.nix
  ];

  services.syncthing = {
    folders = {
      "Sync-Linux" = {
        # Name of folder in Syncthing, also the folder ID
        id = "Sync-Linux";
        enable = true;
        path = "${config.my.homeDir}/Sync"; # Which folder to add to Syncthing
        devices = ["fwnixos" "nixos-2022-desktop"]; # Which devices to share the folder with
        versioning = defaultVersioning;
      };

      "Notes-Shared" = {
        id = "evgke-fvs53";
        enable = true;
        path = "${config.my.homeDir}/Notes/Notes-Shared";
        devices = ["fwnixos" "nixos-2022-desktop"];
        versioning = defaultVersioning;
      };

      "Notes-Personal" = {
        id = "jjbsv-stmrg";
        enable = true;
        path = "${config.my.homeDir}/Notes/Notes-Personal";
        devices = ["fwnixos" "nixos-2022-desktop"];
        versioning = defaultVersioning;
      };

      # Calibre work library (technical reference material, including
      # e.g. books, manuals, quick reference cards)
      "Calibre-Work" = {
        id = "nqtzd-2klbn";
        enable = true;
        path = "/media/disk2/Books/Calibre-Work";
        devices = [
          "nixos-2022-desktop"
          #"work-laptop"
        ];
        versioning = defaultVersioning;
      };
      "Photos-Pixel4a" = {
        id = "pixel_4a_d88y-photos";
        enable = true;
        type = "receiveonly";
        path = "/media/disk2/Backup-Photos/Sam-Pixel4a-Syncthing";
        devices = ["pixel4a"];
        versioning = photoVersioning;
      };
      "Photos-Pixel8" = {
        id = "pixel_8_22n8-photos";
        enable = true;
        type = "receiveonly";
        path = "/media/disk2/Backup-Photos/Sam-Pixel8-Syncthing";
        devices = ["pixel8"];
        versioning = photoVersioning;
      };
      "PhoneTransfer" = {
        id = "ntcgb-rnrl5";
        enable = true;
        path = "/storage/Sam/PhoneTransfer";
        devices = ["pixel4a" "pixel8"];
        versioning = defaultVersioning;
      };
    };
  };
}
