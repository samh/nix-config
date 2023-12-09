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
      maxAge = "365"; # Syncthing doc says days; is Nix version the same?
      # versionsPath = ".stversions";
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
    };
  };
}
