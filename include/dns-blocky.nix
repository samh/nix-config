# DNS server - blocky
{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./metadata.nix
  ];

  # TODO: maybe should have an option that says this DNS is "public"?
  # Could let it through firewall, and possibly change some other settings.
  options = {};

  config = {
    services.blocky = {
      enable = true;
      settings = {
        ports = {
          dns = lib.mkDefault 53;
          http = lib.mkDefault 4000;
        };
        connectIPVersion = "v4";
        # Cloudflare upstream DNS servers
        upstream.default = [
          "https://one.one.one.one/dns-query"
          "https://dns.quad9.net/dns-query"
        ];
        bootstrapDns = {
          upstream = "https://one.one.one.one/dns-query";
          ips = ["1.1.1.1" "1.0.0.1"];
        };
        queryLog = {
          # Defaults to console if not set, which gets logged to the journal.
          type = "none";
        };
        customDNS = let
          dom = config.local.base_domain;
          hosts = config.myMetadata.hosts;
        in {
          # Don't make TTL too long, since we want to be able to change
          # IP addresses quickly or fix mistakes.
          customTTL = 5 m;
          # TODO: iterate over all hosts
          mapping = {
            "kirby.${dom}" = hosts.kirby.ip_address;
            "yoshi.${dom}" = hosts.yoshi.ip_address;
          };
        };
      };
    };
    # Configure to use own local DNS server
    networking.nameservers = ["127.0.0.1"];
  };
}
