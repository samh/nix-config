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
      qemu.ovmf.enable = lib.mkDefault true;
      # Added OVMFFull for Windows 11 - not sure if this is needed or not.
      qemu.ovmf.packages = [pkgs.OVMFFull.fd];
      qemu.swtpm.enable = lib.mkDefault true;
      # Don't start VMs that were running at shutdown
      # (autostart VMs should still be started)
      onBoot = lib.mkDefault "ignore";
      # Shut down running VMs, instead of trying to suspend them
      onShutdown = lib.mkDefault "shutdown";
      # Number of guests that will be shut down concurrently
      # (if onShutdown = "shutdown").
      parallelShutdown = lib.mkDefault 4;
      # Number of seconds to wait for a guest to shut down; defaults to 300
      # (too long).
      shutdownTimeout = lib.mkDefault 60;
    };
    # "Install the SPICE USB redirection helper with setuid privileges.
    # This allows unprivileged users to pass USB devices connected to this
    # machine to libvirt VMs, both local and remote. Note that this allows
    # users arbitrary access to USB devices."
    #spiceUSBRedirection.enable = true;
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
