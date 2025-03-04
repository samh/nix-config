{
  config,
  pkgs,
  ...
}: let
  image = "docker.io/archivebox/archivebox:latest";
  #data_dir = "/var/lib/archivebox";
  data_dir = "/data/appdata/archivebox/data";
  # Host and port for the container to listen on (outside the container)
  host = "127.0.0.1";
  port = 8000;
in {
  # Create config directory
  systemd.tmpfiles.rules = [
    "d ${data_dir} 0770 - -"
  ];

  # Requires manual setup for the first run. I think the typical NixOS
  # thing to do might be to create a "PreExec" script that checks whether
  # the data directory is empty, and if so, runs the archivebox init command.
  #
  # Initial Setup (make sure uidmap matches extraOptions below):
  # mkdir /var/lib/archivebox
  # podman run --uidmap=0:124000000:65535 -v /var/lib/archivebox:/data:U -it docker.io/archivebox/archivebox init --setup
  #
  # Permissions are weird on ArchiveBox because by default it runs as root
  # then switches to a user (PUID/PGID), default id 911. So I am explicitly
  # setting a uidmap to map the container to exact user IDs.
  virtualisation.oci-containers.containers.archivebox = {
    image = "docker.io/archivebox/archivebox:latest";
    # Not sure yet how to manage the permissions to get this container to work.
    # :U recursively chown the directory, but it is to root inside the container.
    # (archivebox refuses to run with PUID=0).
    # Seems like there should be a nicer way to handle this. I'm not clear on all
    # the details of userns=auto yet; the mappings might not always be the same.
    # Maybe manually do the mappings to something static?
    autoStart = true;
    labels = {
      "io.containers.autoupdate" = "registry";
    };
    ports = ["${host}:${toString port}:8000"];
    volumes = [
      # :U does not chown to the right user, because container starts as
      # "root". To fix permissions manually, chown to the archivebox user
      # ID shown below, e.g.: "chown -R 124000911:124000911 /var/lib/archivebox"
      "${data_dir}:/data"
    ];
    environment = {
      ALLOWED_HOSTS = "*";
      SAVE_ARCHIVE_DOT_ORG = "False";
    };
    extraOptions = [
      # root=124000000 (124,000,000)
      # archivebox (911) = 124000911
      "--uidmap=0:124000000:65535"
      # gidmap defaults to the same as uidmap
    ];
  };

  services.nginx.virtualHosts."archivebox" = {
    serverName = "archivebox.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://${host}:${toString port}";
      proxyWebsockets = false;
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
  };
}
