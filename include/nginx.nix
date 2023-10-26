# nginx for reverse proxy
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.nginx;
in {
  options = {
    my.nginx = {
      enable = lib.mkEnableOption "Enable nginx with typical settings";
      openFirewall = lib.mkEnableOption "Open firewall for HTTP(s)";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.nginx = {
        enable = true;
        # jellyfin: default "might not be enough for some posters"
        clientMaxBodySize = lib.mkDefault "20M";
        recommendedGzipSettings = true;
        recommendedOptimisation = true;
        # Recommended prxoy settings include headers Host, X-Real-IP,
        # X-Forwarded-For, X-Forwarded-Proto, X-Forwarded-Host,
        # X-Forwarded-Server via an include of a file named
        # 'nginx-recommended-proxy-headers.conf', plus other
        # proxy settings.
        # https://github.com/NixOS/nixpkgs/blob/nixos-23.05/nixos/modules/services/web-servers/nginx/default.nix
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
      };
    })
    (lib.mkIf (cfg.enable && cfg.openFirewall) {
      # Serve HTTP and HTTPS
      networking.firewall.allowedTCPPorts = [80 443];
    })
  ];
}
