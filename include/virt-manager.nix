{ config, pkgs, ... }:

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
    virt-manager
  ];

  boot.kernel.sysctl = {
    # Required for libvirt NAT to work
    "net.ipv4.ip_forward" = 1;
  };

  #users.groups.libvirtd.members = [ "root" "samh" ];
}
