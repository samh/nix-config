{
  config,
  pkgs,
  ...
}: let
  # this line prevents hanging on network split
  net_automount_opts = [
    "x-systemd.after=network-online.target"
    "x-systemd.automount"
    "noauto"
    "_netdev"
    "x-systemd.idle-timeout=60"
    "x-systemd.device-timeout=5s"
    "x-systemd.mount-timeout=5s"
  ];
  samba_permission_opts = [
    "uid=${toString config.users.users.${config.my.user}.uid}"
    "file_mode=0660"
    "dir_mode=0770"
  ];
in {
  # Remote filesystems
  # https://nixos.wiki/wiki/Samba
  # For mount.cifs, required unless domain name resolution is not needed.
  environment.systemPackages = [pkgs.cifs-utils];

  boot.supportedFilesystems.nfs = true;

  fileSystems."/mnt/storage" = {
    device = "//yoshi.hartsfield.xyz/storage";
    fsType = "cifs";
    options =
      net_automount_opts
      ++ samba_permission_opts
      ++ [
        "credentials=/root/smb-secrets"
      ];
  };
  # Jellyfin library (writes with "multimedia" group permissions)
  fileSystems."/mnt/Library" = {
    device = "//yoshi.hartsfield.xyz/Library";
    fsType = "cifs";
    options =
      net_automount_opts
      ++ samba_permission_opts
      ++ [
        "credentials=/root/smb-secrets"
        "gid=${toString config.users.groups.multimedia.gid}"
      ];
  };
  # Audiobooks library (writes with "audiobookshelf" group permissions)
  fileSystems."/mnt/AudiobooksLibrary" = {
    device = "//yoshi.hartsfield.xyz/AudiobooksLibrary";
    fsType = "cifs";
    options =
      net_automount_opts
      ++ samba_permission_opts
      ++ [
        "credentials=/root/smb-secrets"
        "gid=${toString config.users.groups.multimedia.gid}"
      ];
  };
  # Retro games
  #  fileSystems."/mnt/Retro" = {
  #    device = "//yoshi.hartsfield.xyz/Retro";
  #    fsType = "cifs";
  #    options =
  #      net_automount_opts
  #      #++ samba_permission_opts
  #      ++ [
  #        "unix"
  #        "uid=${toString config.users.users.${config.my.user}.uid}"
  #        "gid=${toString config.users.groups.users.gid}"
  #        "credentials=/root/smb-secrets"
  #      ];
  #  };

  # Retro games - NFS for proper permission preservation
  fileSystems."/mnt/Retro" = {
    device = "${config.my.metadata.hosts.yoshi.tailscale_address}:/Retro";
    fsType = "nfs";
    options =
      net_automount_opts
      ++ [
        "nfsvers=4.2"
        "rw"
      ];
  };

  # Add tmpfiles rule to create symbolic link from /storage to /mnt/storage
  systemd.tmpfiles.rules = [
    "L /storage - - - - /mnt/storage"
  ];
}
