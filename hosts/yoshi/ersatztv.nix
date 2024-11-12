{
  config,
  pkgs,
  ...
}: let
  image = "docker.io/jasongdove/ersatztv:latest-vaapi";
  config_dir = "/var/lib/ersatztv";
  # Host and port for the container to listen on (outside the container)
  host = "127.0.0.1";
  port = 8409;
in {
  # Create config directory
  systemd.tmpfiles.rules = [
    "d ${config_dir} 0770 - -"
  ];

  # Quadlet options are documented here:
  # https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
  environment.etc."containers/systemd/ersatztv.container".text = ''
    [Unit]
    Description=ErsatzTV Container
    Wants=network-online.target jellyfin.service
    After=network-online.target jellyfin.service

    [Container]
    Environment=TZ=${config.time.timeZone}
    Image=${image}
    PublishPort=${host}:${toString port}:8409
    UserNS=auto
    Volume=${config_dir}:/root/.local/share/ersatztv:U
    # Mount Jellyfin's library directory into the container, at the same
    # location that Jellyfin uses.
    Volume=/storage/Library:/data:ro
    # "To limit the writing to an SSD drive"
    # Creates a tmpfs mount (RAM disk) for transcoding
    Mount=type=tmpfs,destination=/root/.local/share/etv-transcode

    [Install]
    WantedBy=default.target
  '';

  services.nginx.virtualHosts."ersatztv" = {
    serverName = "tv.${config.my.hostDomain}";
    locations."/" = {
      proxyPass = "http://${host}:${toString port}";
      # I'm not sure if ErzatzTV uses websockets or not.
      proxyWebsockets = true;
    };
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
  };

  # Create a wrapper script for updating the container manually.
  # For automatic updates, using the built-in podman mechanism might be better,
  # if the rollbacks work well (if I can't figure out how to get that to do
  # a custom health check, then it might be worth writing a special service
  # for that).
  systemd.services.ersatztv-update = {
    description = "Update the ErsatzTV container";
    serviceConfig = {
      Type = "oneshot";
      # Would be nice if this only restarted if the image changed...
      ExecStart = "${pkgs.podman}/bin/podman pull ${image} && ${pkgs.systemd}/bin/systemctl restart ersatztv.service";
    };
  };
}
