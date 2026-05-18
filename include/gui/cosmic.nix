# COSMIC Desktop Environment
#
# See https://wiki.nixos.org/wiki/COSMIC
#
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.gui.cosmic;
in {
  options = {
    my.gui.cosmic.enable = lib.mkEnableOption "COSMIC desktop";
  };

  imports = [
    ../common-gui.nix
  ];

  config = lib.mkIf cfg.enable {
    # Enable the Wayland session
    my.gui.enable = lib.mkDefault true;
    my.gui.sound.enable = lib.mkDefault true;

    # Enable the COSMIC login manager
    services.displayManager.cosmic-greeter.enable = true;

    # Enable the COSMIC desktop environment
    services.desktopManager.cosmic.enable = true;

    # Exclude packages that are installed by default with COSMIC
    # environment.cosmic.excludePackages = with pkgs; [
    #   cosmic-edit
    # ];

    environment.systemPackages = with pkgs; [
      # Additional packages as needed
    ];

    # Optional: Enable system76-scheduler for slight performance improvement
    # services.system76-scheduler.enable = true;

    # Optional: Enable unstable wlr-data-control protocol for clipboard manager support
    # NOTE: This means all windows have global clipboard access.
    # environment.sessionVariables.COSMIC_DATA_CONTROL_ENABLED = "1";

    # Disable Firefox's libadwaita theming so COSMIC theming is reflected
    programs.firefox.preferences = {
      "widget.gtk.libadwaita-colors.enabled" = false;
    };
  };
}
