#
# This is a basic configuration.nix that can be used to install NixOS
# on a new system (e.g. by copying to the install USB), with the intention
# of being replaced later by the real configuration from my git repo.
#
# Things that should be edited:
#
#  - The hostname - should be set so the correct flake is selected by default
#    when building the real config
#  - Disable or change desktop manager if desired
#
# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).
{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Use the grub EFI boot loader.
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    useOSProber = false;
    configurationLimit = 30;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "initial-install"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/New_York";

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
  services.xserver.enable = true;
  # Xfce Desktop
  services.desktopManager.xfce.enable = true;
  # KDE Plasma Desktop
  #services.displayManager.sddm.enable = true;
  #services.desktopManager.plasma6.enable = true;
  # GNOME Desktop
  #services.displayManager.gdm.enable = true;
  #services.desktopManager.gnome.enable = true;
  # Budgie
  #services.desktopManager.budgie.enable = true;
  #services.displayManager.lightdm.enable = true;

  # Virtual Machine guest stuff - allow copy/paste
  # (Probably won't hurt if not a VM?)
  services.spice-vdagentd.enable = true;
  services.spice-autorandr.enable = true;
  services.spice-webdavd.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.samh = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = ["wheel"]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFUXbz1JybJ80kgBWGFG8a0QOjmeMfpCH7l4uZTZTCo7 fedora2020desktop-2022-02-05"
    ];
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    git # Required to build flakes
    #neovim
    nh # Yet another nix cli helper
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  programs.firefox.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

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
  system.stateVersion = "24.05"; # Did you read the comment?
}
