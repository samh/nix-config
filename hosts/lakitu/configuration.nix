{
  config,
  lib,
  pkgs,
  ...
}: let
  myIP = config.my.metadata.hosts.${config.networking.hostName}.ip_address;
  myTailscaleIP = config.my.metadata.hosts.${config.networking.hostName}.tailscale_address;
in {
  imports = [
    ../../include/common.nix
    ../../include/dns-blocky.nix
    ../../include/virt-manager.nix

    ./network.nix

    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the grub boot loader (EFI mode)
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = false;
    configurationLimit = 20;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "lakitu"; # Define your hostname.

  # For networking - see ./network.nix

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  # Enable the X11 windowing system.
  # This machine is supposed to be a router, so if something is not working,
  # we might not be able to access it to troubleshoot via the network. In
  # that case, it could be useful to have a local display to troubleshoot.
  services.xserver.enable = true;
  # Budgie added about 2.6GB (2023-12-12 on NixOS 23.11)
  #services.xserver.desktopManager.budgie.enable = true;
  #services.xserver.displayManager.lightdm.enable = true;
  #environment.budgie.excludePackages = with pkgs; [
  #  vlc
  #];
  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  # Disable GNOME apps
  services.gnome.core-utilities.enable = false;
  services.gnome.tinysparql.enable = false;
  services.gnome.localsearch.enable = false;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    dconf-editor
    gnome-calculator
    gnome-disk-utility
    gnome-logs
    gnome-nettool
    seahorse # keyring
    gnome-logs
    gnome-system-monitor
    gnome-terminal
    gnome-text-editor
    gnome-tweaks
    nautilus
    nh # Nix helper
    vscodium # for local editing of NixOS config in case network goes down
    doit # task runner for my NixOS config
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  programs.file-roller.enable = true;
  programs.firefox.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # There are no btrfs fileSystems on this host
  services.btrfs.autoScrub.enable = false;

  my.common.tailscale.enable = true;

  # Start VM with the system. Define this declaratively instead of setting
  # the VM to autostart; that allows it to be tied to the NixOS configuration,
  # in case I want to test alternate router setups (i.e. rolling back will
  # start the correct VM or not).
  systemd.services.opnsense = {
    description = "Start opnsense VM";
    requires = ["libvirtd.service"];
    after = ["libvirtd.service" "sys-devices-virtual-net-br0.device"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      Group = "root";
    };
    # Writes a script that is called by ExecStart
    script = ''
      # Start the VM if it's not already running.
      # "list" without "--all" only shows running VMs.
      if ! ${pkgs.libvirt}/bin/virsh list --name | grep -q '^opnsense$'; then
        ${pkgs.libvirt}/bin/virsh start opnsense
      fi
    '';
  };

  # Enable DNS server.
  # Serves DNS for the rest of the network.
  my.dns.blocky.enable = true;
  services.blocky.settings.ports = {
    # Bind to localhost, main IP address, and Tailscale IP address.
    dns = "127.0.0.1:53,${myIP}:53,${myTailscaleIP}:53";
  };
  # Listen for DNS requests on the bridge interface (LAN side).
  networking.firewall.interfaces."br1".allowedTCPPorts = [53];
  networking.firewall.interfaces."br1".allowedUDPPorts = [53];

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
