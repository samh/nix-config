{
  config,
  lib,
  ...
}: {
  config = {
    boot.kernel.sysctl = {
      # Enable sysrq keyboard shortcuts; see
      # https://wiki.archlinux.org/title/Keyboard_shortcuts#Kernel_(SysRq)
      "kernel.sysrq" = lib.mkDefault 1;
      # Increase UDP max buffer size to allow for faster QUIC transfers
      # on high-bandwidth connections in Syncthing.
      # https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes
      "net.core.rmem_max" = lib.mkDefault 7500000;
      "net.core.wmem_max" = lib.mkDefault 7500000;
    };
  };
}
