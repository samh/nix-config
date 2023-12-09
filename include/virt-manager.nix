{
  config,
  lib,
  pkgs,
  ...
}:
# Virtualization using KVM with virt-manager
{
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu.ovmf.enable = true;
      qemu.swtpm.enable = true;
      # Don't start VMs that were running at shutdown
      # (autostart VMs should still be started)
      onBoot = "ignore";
      # Shut down running VMs, instead of trying to suspend them
      onShutdown = "shutdown";
    };
  };

  environment.systemPackages = with pkgs; [
    pciutils # lspci
  ];

  # Add virt-manager GUI if X is enabled
  programs.virt-manager.enable = config.services.xserver.enable;

  # Required for libvirt NAT to work
  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkDefault 1;

  #users.groups.libvirtd.members = [ "root" "${config.my.user}" ];
  users.users."${config.my.user}".extraGroups = ["libvirtd"];
}
