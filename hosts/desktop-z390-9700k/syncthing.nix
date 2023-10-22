# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  ...
}: {
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
        "storage-server" = {id = "AL433J4-2HM6N7D-C4HP5FT-6FNPCPI-MYW4T36-7RIEF5B-7J66U2W-BYW7CQ3";};
        "framework-laptop" = {id = "DQ5PQ5T-OEQQGJ5-C67RF4Y-SJR5NIZ-WPFSJQT-YNXFOET-37356WL-P7LWNQH";};
        "pixel4a" = {id = "NPVNVC5-J2CKZF6-6LUH6NF-3NYG6GP-GUERNAO-O35UZUC-L6ADKSK-SPRA3AL";};
        "work-laptop" = {id = "ME2B765-2HQWLAO-A7PRWE3-RP44QKE-UIJTZSH-467P3GF-JE7FSWY-ZYCPQQA";}; # 2013
        "work-laptop-old" = {id = "RNF52NS-62AEXH6-OX6QEAG-ELSLT7R-QLMPMW2-OBQS35Z-ZUDVRUF-PNOH3Q4";};
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
          path = "/home/samh/Sync"; # Which folder to add to Syncthing
          devices = ["framework-laptop" "storage-server"]; # Which devices to share the folder with
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "365"; # Syncthing doc says days; is Nix version the same?
              #              versionsPath = ".stversions";
            };
          };
        };
        "Notes-Shared" = {
          id = "evgke-fvs53";
          enable = true;
          path = "/home/samh/Notes/Notes-Shared";
          devices = [
            "vfio-windows"
            "storage-server"
            "framework-laptop"
            "work-laptop-old"
            "work-laptop"
            "pixel4a"
          ];
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "365";
            };
          };
        };
        "Notes-Personal" = {
          id = "jjbsv-stmrg";
          enable = true;
          path = "/home/samh/Notes/Notes-Personal";
          devices = ["vfio-windows" "storage-server" "framework-laptop" "pixel4a"];
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "365";
            };
          };
        };
        # Calibre work library (technical reference material, including
        # e.g. books, manuals, quick reference cards)
        "Calibre-Work" = {
          id = "nqtzd-2klbn";
          enable = true;
          path = "/samh/Calibre-Work";
          devices = [
            "storage-server"
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
