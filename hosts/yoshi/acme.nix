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
  security.acme.certs."${config.local.hostDomain}" = {
    domain = "*.${config.local.hostDomain}";
    dnsProvider = "cloudflare";
    credentialsFile = "/root/acme.env";
    group = "nginx";
  };
}