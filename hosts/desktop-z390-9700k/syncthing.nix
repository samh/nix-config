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
    ../include/metadata.nix
  ];
  services = {
    syncthing = {
      enable = true;
      user = "${config.my.user}";
      dataDir = "${config.my.homeDir}/Documents"; # Default folder for new synced folders
      configDir = "${config.my.homeDir}/.config/syncthing"; # Folder for Syncthing's settings and keys
      openDefaultPorts = true;

      overrideDevices = true; # overrides any devices added or deleted through the WebUI
      overrideFolders = true; # overrides any folders added or deleted through the WebUI
      devices = {
        "framework-laptop" = {id = config.my.metadata.hosts.fwnixos.syncthing_id;};
        "pixel4a" = {id = config.my.metadata.hosts.pixel4a.syncthing_id;};
        "work-laptop" = {id = "ME2B765-2HQWLAO-A7PRWE3-RP44QKE-UIJTZSH-467P3GF-JE7FSWY-ZYCPQQA";}; # 2023
        "work-laptop-old" = {id = "RNF52NS-62AEXH6-OX6QEAG-ELSLT7R-QLMPMW2-OBQS35Z-ZUDVRUF-PNOH3Q4";};
        "yoshi" = {id = config.my.metadata.hosts.yoshi.syncthing_id;};
        # VFIO VM (Windows) - maybe a Samba shared folder would be better, to
        # avoid having to run Syncthing in the VM.
        # Linux VFIO VMs can use a 9p shared folder from the host.
        "vfio-windows" = {id = "CNJBSUE-KIERN7M-6WKA2YC-OO4EDQB-FKM2YJT-HZIOYOF-WKQ6NPJ-CEAHJAU";};
      };
      folders = {
        "Sync-Linux" = {
          # Name of folder in Syncthing, also the folder ID
          id = "Sync-Linux";
          enable = true;
          path = "${config.my.homeDir}/Sync"; # Which folder to add to Syncthing
          devices = ["framework-laptop" "yoshi"]; # Which devices to share the folder with
          versioning = defaultVersioning;
        };
        "Notes-Shared" = {
          id = "evgke-fvs53";
          enable = true;
          path = "${config.my.homeDir}/Notes/Notes-Shared";
          devices = [
            "vfio-windows"
            "yoshi"
            "framework-laptop"
            "work-laptop-old"
            "work-laptop"
            "pixel4a"
          ];
          versioning = defaultVersioning;
        };
        "Notes-Personal" = {
          id = "jjbsv-stmrg";
          enable = true;
          path = "${config.my.homeDir}/Notes/Notes-Personal";
          devices = ["vfio-windows" "yoshi" "framework-laptop" "pixel4a"];
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
      };
    };
  };
}
