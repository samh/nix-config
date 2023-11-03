{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.my.sysctl;
in {
  options = {
    # NixOS doesn't like when you define sysctl options multiple times, so
    # add the ones I want as options.
    my.sysctl = {
      net.ipv4.ip_forward = mkOption {
        type = types.bool;
        default = true;
        description = "Enable IPv4 forwarding";
      };
      net.ipv6.conf.all.forwarding = mkOption {
        type = types.bool;
        default = true;
        description = "Enable IPv6 forwarding";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.net.ipv4.ip_forward {
      boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
    })
    (mkIf cfg.net.ipv6.conf.all.forwarding {
      boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
    })
  ];
}
