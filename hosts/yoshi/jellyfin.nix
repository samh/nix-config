{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.common;
in {
  config = lib.mkMerge [
    {
      services.jellyfin = {
        enable = true;
        group = "multimedia";
      };
    }
    (lib.mkIf config.services.jellyfin.enable {
      # Bind the library directory to the same place as it was in the container
      # on the old server, because it takes some database editing to change it.
      # The mount is only visible inside the jellyfin service.
      systemd.services.jellyfin.serviceConfig.BindPaths = "/storage/Library:/data";
      systemd.services.jellyfin.unitConfig.RequiresMountsFor = "/storage/Library";
      # https://jellyfin.org/docs/general/networking/index.html
      # 8096/tcp is used by default for HTTP traffic. You can change this in the dashboard.
      # 8920/tcp is used by default for HTTPS traffic. You can change this in the dashboard.
      # We're using nginx as reverse proxy. Sometimes might want to have access to
      # the port on the local network as a backup.
      networking.firewall.allowedTCPPorts = [8096];
      #
      # 1900/udp is used for service auto-discovery. This is not configurable.
      # (DLNA also uses this port and is required to be in the local subnet.)
      #
      # 7359/udp is also used for auto-discovery. This is not configurable.
      # Allows clients to discover Jellyfin on the local network. A broadcast
      # message to this port with Who is JellyfinServer? will get a JSON
      # response that includes the server address, ID, and name.
      networking.firewall.allowedUDPPorts = [1900 7359];

      # Jellyfin reverse proxy
      # See https://jellyfin.org/docs/general/networking/nginx for its recommended
      # nginx configuration.
      services.nginx.clientMaxBodySize = "20M"; # jellyfin: default "might not be enough for some posters"
      services.nginx.virtualHosts."jellyfin" = {
        serverName = "jellyfin.${config.my.hostDomain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          proxyWebsockets = true;
        };
        forceSSL = true;
        useACMEHost = config.my.hostDomain;
      };
    })
  ];
}
