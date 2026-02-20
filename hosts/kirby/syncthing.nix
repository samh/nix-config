{
  config,
  lib,
  ...
}: let
  # Kirby receives notes folders so notes-history services can snapshot them.
  defaultVersioning = {
    type = "staggered";
    params = {
      cleanInterval = "3600";
      maxAge = "365";
    };
  };
in {
  imports = [
    ../include/syncthing.nix
  ];

  services.syncthing.settings = {
    folders = {
      "Notes-Shared" = {
        id = "evgke-fvs53";
        enable = true;
        path = "${config.my.homeDir}/Notes/Notes-Shared";
        devices = ["nixos-2022-desktop" "fwnixos" "yoshi" "fwdesktop-cachy" "work-laptop" "pixel8"];
        versioning = defaultVersioning;
      };
      "Notes-Personal" = {
        id = "jjbsv-stmrg";
        enable = true;
        path = "${config.my.homeDir}/Notes/Notes-Personal";
        devices = ["nixos-2022-desktop" "fwnixos" "yoshi" "fwdesktop-cachy" "pixel8"];
        versioning = defaultVersioning;
      };
    };
  };
}
