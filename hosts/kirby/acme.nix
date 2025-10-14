{
  config,
  lib,
  ...
}: {
  # Cloudflare API key should be created per instructions at
  # https://go-acme.github.io/lego/dns/cloudflare/ and set in
  # sops secrets:
  #   CF_DNS_API_TOKEN=...
  #
  sops.secrets = {
    acme-env = {};
  };
  #  security.acme.defaults = {
  #    dnsProvider = "cloudflare";
  #    credentialsFile = config.sops.secrets."acme-env".path;
  #  };
  security.acme.certs."kirby.${config.my.baseDomain}" = {
    domain = "*.kirby.${config.my.baseDomain}";
    # Was delegated to DigitalOcean for a while; now moved back to Cloudflare,
    # to use digitalocean for sandbox/testing machines.
    dnsProvider = "cloudflare";
    # dnsProvider = "digitalocean";
    credentialsFile = config.sops.secrets."acme-env".path;
    group = "nginx";
  };
}
