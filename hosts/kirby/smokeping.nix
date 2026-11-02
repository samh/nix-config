{config, ...}: let
  dashboard = "smokeping.${config.my.hostDomain}";
in {
  services.smokeping = {
    enable = true;
    host = dashboard;
    hostName = dashboard;
    cgiUrl = "https://${dashboard}/smokeping.fcgi";
    owner = "samh";
    # Thirty-second samples retain detail for seven days, then consolidate to
    # six-minute samples for sixty days and hourly samples for a year.
    # Changing step or pings later requires migrating the existing RRD files.
    databaseConfig = ''
      step = 30
      pings = 20
      AVERAGE 0.5 1 20160
      AVERAGE 0.5 12 14400
      MIN     0.5 12 14400
      MAX     0.5 12 14400
      AVERAGE 0.5 120 8760
      MIN     0.5 120 8760
      MAX     0.5 120 8760
    '';
    targetConfig = ''
      probe = FPing
      menu = Network
      title = Network latency and packet loss from kirby
      remark = Measurements originate behind OPNsense. Public-target loss alone does not identify an ISP fault.

      + Local
      menu = Local network
      title = Local network and router host

      ++ Router
      menu = OPNsense LAN
      title = OPNsense LAN - 192.168.5.1
      host = 192.168.5.1

      ++ Lakitu
      menu = lakitu
      title = OPNsense VM host - 192.168.10.10
      host = 192.168.10.10

      + Gateway
      menu = AT&T gateway
      title = AT&T gateway management interface

      ++ ATT
      menu = Gateway
      title = AT&T gateway - 192.168.1.254
      host = 192.168.1.254

      + Internet
      menu = Internet
      title = Public IPv4 targets independent of DNS

      ++ Cloudflare
      menu = Cloudflare primary
      title = Cloudflare - 1.1.1.1
      host = 1.1.1.1

      ++ CloudflareSecondary
      menu = Cloudflare secondary
      title = Cloudflare - 1.0.0.1
      host = 1.0.0.1

      ++ Quad9
      menu = Quad9 primary
      title = Quad9 - 9.9.9.9
      host = 9.9.9.9

      ++ Quad9Secondary
      menu = Quad9 secondary
      title = Quad9 - 149.112.112.112
      host = 149.112.112.112

      ++ Google
      menu = Google
      title = Google - 8.8.8.8
      host = 8.8.8.8
    '';
  };

  services.nginx.virtualHosts.smokeping = {
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
    # SmokePing has no login: keep the network topology and graphs on the
    # home network and tailnet, including direct IPv6 tailnet connections.
    extraConfig = ''
      allow 127.0.0.1;
      allow ::1;
      allow 192.168.0.0/16;
      allow 100.64.0.0/10;
      allow fd7a:115c:a1e0::/48;
      deny all;
    '';
  };
}
