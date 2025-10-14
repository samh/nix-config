{
  config,
  inputs,
  ...
}: let
  # Not under host subdomain, just under the base domain
  openwebui_host = "openwebui.${config.my.baseDomain}";
  openwebui_backend = "127.0.0.1:8081";
in {
  security.acme.certs."${openwebui_host}" = {
    dnsProvider = "cloudflare";
    # sops.secrets.acme.env configured in acme.nix
    credentialsFile = config.sops.secrets."acme-env".path;
    #    group = "caddy";
    group = "nginx";
  };

  # Open WebUI is running as a podman container.
  # See ~/src/ai-stack/open-webui
  #
  #  services.caddy.enable = true;
  #  services.caddy.virtualHosts."${openwebui_host}" = {
  #    useACMEHost = openwebui_host;
  #    extraConfig = ''
  #      reverse_proxy ${openwebui_backend}
  #    '';
  #  };
  services.nginx.virtualHosts."openwebui" = {
    serverName = openwebui_host;
    locations."/" = {
      proxyPass = "http://${openwebui_backend}";
    };
    forceSSL = true;
    useACMEHost = openwebui_host;
  };
}
