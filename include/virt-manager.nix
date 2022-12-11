{ config, pkgs, ... }:

# Virtualization using KVM with virt-manager
{
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu.ovmf.enable = true;
      qemu.swtpm.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    pciutils # lspci
    virt-manager
  ];

  #users.groups.libvirtd.members = [ "root" "samh" ];
}
