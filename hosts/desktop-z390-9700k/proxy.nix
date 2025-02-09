{
  config,
  inputs,
  ...
}: let
  openwebui_host = "openwebui.${config.my.baseDomain}";
in {
  sops.secrets = {
    acme-env = {};
  };

  security.acme.certs."${openwebui_host}" = {
    dnsProvider = "cloudflare";
    credentialsFile = config.sops.secrets."acme-env".path;
    group = "caddy";
  };

  services.caddy.enable = true;
  # Proxy to the service running on the VM
  services.caddy.virtualHosts."${openwebui_host}" = {
    useACMEHost = openwebui_host;
    extraConfig = ''
      reverse_proxy ${config.my.metadata.vms.bowser.internal_ip}:8080
    '';
  };

  # Allow HTTP(S) over Tailscale
  networking.firewall.interfaces.tailscale0 = {
    allowedTCPPorts = [80 443];
  };
}
