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
  security.acme.certs."${config.my.hostDomain}" = {
    domain = "*.${config.my.hostDomain}";
    dnsProvider = "cloudflare";
    credentialsFile = config.sops.secrets."acme-env".path;
    group = "nginx";
  };
}
