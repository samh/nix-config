# homarr.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  name = "homarr";
  user = "homarr";
  group = "homarr";

  #container_tag = "latest";
  container_tag = "v1.48.0";

  dataDir = "/var/lib/homarr";
  appDataDir = "${dataDir}/appdata";

  # Homarr listens on 7575 in-container by default.
  homarrPort = 7575;
in {
  #### Dedicated (non-root) user for rootless Podman ####
  users.groups.${group} = {};
  users.users.${user} = {
    isSystemUser = true;
    group = group;
    home = dataDir;
    createHome = true;
    # Unclear if we should use linger or not; the module warns if we enable
    # "Podman container homarr is configured as rootless (user homarr) with
    #  `--sdnotify=conmon`, but lingering for this user is turned on."
    # But I'm not clear on why this is. Could also try setting
    # sdnotify = "healthy".
    linger = false;
    autoSubUidGidRange = true;
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 ${user} ${group} - -"
    "d ${appDataDir} 0750 ${user} ${group} - -"
  ];

  #### Secrets: SECRET_ENCRYPTION_KEY via sops-nix ####
  # Put this in your sops file:
  # homarr-secret-encryption-key: "<64 hex chars>"
  # Generate: openssl rand -hex 32
  sops.secrets."homarr-secret-encryption-key" = {
    owner = user;
    group = group;
    mode = "0400";
  };

  # Render an env-file at activation time (not in the Nix store).
  sops.templates."homarr.env" = {
    owner = user;
    group = group;
    mode = "0400";
    content = ''
      SECRET_ENCRYPTION_KEY=${config.sops.placeholder."homarr-secret-encryption-key"}
    '';
  };

  #### Rootless Podman container ####
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.${name} = {
    image = "ghcr.io/homarr-labs/homarr:${container_tag}";
    autoStart = true;

    # Bind ONLY to localhost; nginx will proxy to it.
    ports = ["127.0.0.1:${toString homarrPort}:7575"];

    # Homarr expects its persistent data in /appdata.
    volumes = [
      "${appDataDir}:/appdata"
      # Optional: Docker integration socket (only if you really want it)
      # "/var/run/docker.sock:/var/run/docker.sock"
    ];

    environmentFiles = [config.sops.templates."homarr.env".path];

    # Make Podman run it rootlessly as the dedicated user
    podman.user = user;

    # Optional hardening (safe defaults; can remove if you prefer)
    extraOptions = [
      "--security-opt=no-new-privileges"
      # Used for non-lingering user (default is systemd, which fails and
      # falls back to this with a warning if user is not lingering)
      "--cgroup-manager=cgroupfs"
    ];
  };

  systemd.services."podman-${name}".after = ["systemd-tmpfiles-setup.service"];

  services.nginx.virtualHosts."homarr" = {
    serverName = "homarr.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString homarrPort}";
      proxyWebsockets = true;
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
  };
}
