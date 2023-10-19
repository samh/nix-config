{
  config,
  lib,
  ...
}: {
  # Cloudflare API key should be created per instructions at
  # https://go-acme.github.io/lego/dns/cloudflare/ and set in
  # /root/acme.env:
  #   CF_DNS_API_TOKEN=...
  #

  #  security.acme.defaults = {
  #    dnsProvider = "cloudflare";
  #    credentialsFile = "/root/acme.env";
  #  };
  security.acme.certs."kirby.${config.local.base_domain}" = {
    domain = "*.kirby.${config.local.base_domain}";
    # This subdomain is currently delegated to DigitalOcean
    #dnsProvider = "cloudflare";
    dnsProvider = "digitalocean";
    credentialsFile = "/root/acme.env";
    group = "nginx";
  };
}
