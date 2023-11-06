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
      kernel.sysrq = mkOption {
        type = types.int;
        default = 1;
        description = "Enable sysrq keyboard shortcuts; see https://wiki.archlinux.org/title/Keyboard_shortcuts#Kernel_(SysRq)";
      };
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
      vm.overcommit_memory = mkOption {
        type = types.int;
        default = 0;
        description = "Enable overcommitting of memory";
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
    (mkIf (cfg.vm.overcommit_memory > 0) {
      boot.kernel.sysctl."vm.overcommit_memory" = cfg.vm.overcommit_memory;
    })
    {
      boot.kernel.sysctl."kernel.sysrq" = cfg.kernel.sysrq;
    }
  ];
}
