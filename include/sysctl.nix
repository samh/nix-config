{
  config,
  lib,
  ...
}: {
  config = {
    # Enable sysrq keyboard shortcuts; see https://wiki.archlinux.org/title/Keyboard_shortcuts#Kernel_(SysRq)
    boot.kernel.sysctl."kernel.sysrq" = lib.mkDefault 1;
  };
}
