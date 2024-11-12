# DNS server - blocky
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.dns.blocky;
in {
  imports = [
    ./metadata.nix
  ];

  options = {
    my.dns.blocky = {
      enable = lib.mkEnableOption "Enable Blocky DNS server";
      openFirewall = lib.mkEnableOption "Open firewall for DNS server";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      services.blocky = {
        enable = true;
        settings = {
          ports = {
            dns = lib.mkDefault 53;
            http = lib.mkDefault 4000;
          };
          connectIPVersion = "v4";
          # Cloudflare upstream DNS servers
          upstreams.groups.default = [
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
            dom = config.my.baseDomain;
            hosts = config.my.metadata.hosts;
            # Filter all hosts that have an IP address
            hostsWithIp = lib.filterAttrs (name: host: host ? ip_address) hosts;
            # Use mapAttrs' ("map attrs prime") to map the name as well as the value.
            fqdnMappings = lib.attrsets.mapAttrs' (name: value:
              # Add domain to name
                lib.attrsets.nameValuePair "${name}.${dom}"
                # Value is the IP address
                (value.ip_address))
            hostsWithIp; # <--input to "mapAttrs'"
            # Bare hostnames without domain
            unqualifiedMappings = builtins.mapAttrs (name: value: value.ip_address) hostsWithIp;
          in {
            # Don't make TTL too long, since we want to be able to change
            # IP addresses quickly or fix mistakes.
            customTTL = "5m";
            rewrite = {
              # Map "lan" to base domain
              "lan" = config.my.baseDomain;
              # Mapping bare hostnames to domain didn't seem to work
              #"." = config.my.baseDomain;
            };
            # Result should be mapping (attribute set) of host names to IP
            # addresses.
            # For example: { "myhost.domain.xyz" = "1.2.3.4"; }
            mapping = fqdnMappings // unqualifiedMappings;
          };

          conditional = {
            mapping = {
              # Direct Tailscale domain to Tailscale MagicDNS.
              # Allows resolving Tailscale hostnames when using Blocky as DNS.
              "bonobo-triceratops.ts.net" = "100.100.100.100";
              # Direct all *unqualified* hostnames (e.g. just "yoshi") to the
              # router. In particular this allows looking up things like IoT
              # devices that we might not have in our hosts list.
              #"." = "192.168.5.1";
            };
          };
        };
      };
      systemd.services.blocky = {
        # Make sure it's always running and restart if it fails.
        # Some failures (such as failure to bind to IP) were exiting with
        # a 0 status, causing the service to stay down when set to
        # "on-failure".
        serviceConfig = {
          Restart = lib.mkForce "always";
          RestartSec = "60";
        };
      };
      # Configure to use own local DNS server.
      # Disabled because when making changes / testing, we might break
      # the local DNS server.
      #networking.nameservers = ["127.0.0.1"];
    })
    (lib.mkIf (cfg.enable && cfg.openFirewall) {
      networking.firewall.allowedTCPPorts = [53];
      networking.firewall.allowedUDPPorts = [53];
    })
  ];
}
