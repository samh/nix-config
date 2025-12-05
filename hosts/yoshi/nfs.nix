{
  config,
  lib,
  pkgs,
  ...
}: let
  # Note that NFS doesn't have any authentication, so we
  # only allow specific trusted client IPs for NFS.
  nfs_trusted_clients = [
    config.my.metadata.hosts.nixos-2022-desktop.tailscale_address
    config.my.metadata.hosts.fwnixos.tailscale_address
    config.my.metadata.hosts.fwdesktop-cachy.tailscale_address
  ];

  nfs_root = "/srv/nfs";
  nfs_root_options = "ro,fsid=0,no_subtree_check";
  nfs_options = "rw,sync,no_subtree_check,fsid=1,all_squash,anonuid=${toString config.users.users.${config.my.user}.uid},anongid=${toString config.users.groups.storage.gid}";

  # Build exports string with specific IPs only
  nfs_root_exports = lib.concatMapStringsSep " " (ip: "${ip}(${nfs_root_options})") nfs_trusted_clients;
  nfs_exports = lib.concatMapStringsSep " " (ip: "${ip}(${nfs_options})") nfs_trusted_clients;
in {
  # Create pseudo-root directory for NFSv4
  systemd.tmpfiles.rules = [
    "d ${nfs_root} 0755 root root -"
    "d ${nfs_root}/Retro 0755 - - -"
  ];

  # Bind mount actual directories into NFSv4 pseudo-root
  fileSystems."${nfs_root}/Retro" = {
    device = "/storage/Games/Retro";
    options = ["bind"];
  };

  # Enable NFS server
  services.nfs.server = {
    enable = true;
    # NFSv4 pseudo-root and exports
    exports = ''
      ${nfs_root} ${nfs_root_exports}
      ${nfs_root}/Retro ${nfs_exports}
    '';
  };

  # Open firewall for NFS
  networking.firewall = {
    allowedTCPPorts = [2049]; # NFSv4
    allowedUDPPorts = [2049];
  };
}
