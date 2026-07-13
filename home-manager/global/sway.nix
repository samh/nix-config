{pkgs, ...}: {
  wayland.windowManager.sway = {
    enable = true;
    # The NixOS module installs the wrapped Sway package and LightDM session.
    package = null;
    systemd.dbusImplementation = "broker";

    config = rec {
      modifier = "Mod4";
      terminal = "${pkgs.ghostty}/bin/ghostty";
      menu = "${pkgs.fuzzel}/bin/fuzzel";

      # Waybar replaces the default swaybar.
      bars = [];
      startup = [
        {command = "${pkgs.waybar}/bin/waybar";}
        {command = "${pkgs.mako}/bin/mako";}
        {command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";}
        {
          command = "${pkgs.swayidle}/bin/swayidle -w timeout 600 '${pkgs.swaylock}/bin/swaylock -f' before-sleep '${pkgs.swaylock}/bin/swaylock -f' lock '${pkgs.swaylock}/bin/swaylock -f'";
        }
      ];

      keybindings = {
        "${modifier}+Return" = "exec ${terminal}";
        "Mod1+space" = "exec ${menu}";
        "${modifier}+d" = "exec ${menu}";
        "${modifier}+Shift+q" = "kill";

        "${modifier}+h" = "focus left";
        "${modifier}+j" = "focus down";
        "${modifier}+k" = "focus up";
        "${modifier}+l" = "focus right";
        "${modifier}+Shift+h" = "move left";
        "${modifier}+Shift+j" = "move down";
        "${modifier}+Shift+k" = "move up";
        "${modifier}+Shift+l" = "move right";
        "${modifier}+space" = "floating toggle";

        "${modifier}+1" = "workspace number 1";
        "${modifier}+2" = "workspace number 2";
        "${modifier}+3" = "workspace number 3";
        "${modifier}+4" = "workspace number 4";
        "${modifier}+5" = "workspace number 5";
        "${modifier}+6" = "workspace number 6";
        "${modifier}+7" = "workspace number 7";
        "${modifier}+8" = "workspace number 8";
        "${modifier}+9" = "workspace number 9";
        "${modifier}+Shift+1" = "move container to workspace number 1";
        "${modifier}+Shift+2" = "move container to workspace number 2";
        "${modifier}+Shift+3" = "move container to workspace number 3";
        "${modifier}+Shift+4" = "move container to workspace number 4";
        "${modifier}+Shift+5" = "move container to workspace number 5";
        "${modifier}+Shift+6" = "move container to workspace number 6";
        "${modifier}+Shift+7" = "move container to workspace number 7";
        "${modifier}+Shift+8" = "move container to workspace number 8";
        "${modifier}+Shift+9" = "move container to workspace number 9";

        "${modifier}+Control+l" = "exec ${pkgs.swaylock}/bin/swaylock -f";
        "Print" = "exec ${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy";
        "Shift+Print" = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";
      };

      # Output configuration intentionally remains empty until connector names,
      # modes, positions, scale, and rotation can be observed under Sway.
      output = {};
    };
  };
}
