{
  lib,
  pkgs,
  ...
}: let
  powerMenu = "${pkgs.wlogout}/bin/wlogout --no-span --buttons-per-row 4";
in {
  # Keep docs/sway.md in sync with Sway startup, shortcuts, and output settings.
  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      modules-left = [
        "sway/workspaces"
        "sway/mode"
      ];
      modules-center = ["sway/window"];
      modules-right = [
        "pulseaudio"
        "network"
        "cpu"
        "memory"
        "clock"
        "tray"
        "custom/power"
      ];

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = " muted";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
      };
      network = {
        format-wifi = "  {essid}";
        format-ethernet = " Wired";
        format-disconnected = "disconnected";
        tooltip-format = "{ifname}\n{ipaddr}/{cidr}";
      };
      cpu.format = " {usage}%";
      memory = {
        format = "RAM {percentage}%";
        tooltip-format = "{used:0.1f} GiB used of {total:0.1f} GiB";
      };
      clock = {
        format = " {:%a %b %d  %I:%M%p}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };
      tray.spacing = 10;
      "custom/power" = {
        format = "";
        tooltip = true;
        tooltip-format = "Session and power menu";
        on-click = powerMenu;
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "Noto Sans", "Font Awesome 7 Free", sans-serif;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: rgba(32, 32, 32, 0.95);
        color: #eeeeee;
      }

      #workspaces button,
      #mode,
      #window,
      #pulseaudio,
      #network,
      #cpu,
      #memory,
      #clock,
      #tray,
      #custom-power {
        padding: 4px 9px;
      }

      #workspaces button.focused {
        background: #64727d;
      }

      #workspaces button.urgent {
        background: #eb4d4b;
      }

      #custom-power {
        color: #ff7070;
        padding-left: 12px;
        padding-right: 12px;
      }
    '';
  };

  # wlogout expects one JSON object after another, not a JSON array.
  xdg.configFile."wlogout/layout".text =
    (lib.concatMapStringsSep "\n" builtins.toJSON [
      {
        label = "lock";
        action = "${pkgs.swaylock}/bin/swaylock -f";
        text = "Lock";
        keybind = "l";
      }
      {
        label = "logout";
        action = "${pkgs.sway}/bin/swaymsg exit";
        text = "Log out";
        keybind = "e";
      }
      {
        label = "reboot";
        action = "${pkgs.systemd}/bin/systemctl reboot";
        text = "Reboot";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "${pkgs.systemd}/bin/systemctl poweroff";
        text = "Shut down";
        keybind = "s";
      }
    ])
    + "\n";

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
        "Mod1+F4" = "kill";
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
        "${modifier}+Shift+e" = "exec ${powerMenu}";
        "Print" = "exec ${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy";
        "Shift+Print" = "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";
      };

      # Output layouts belong in host-specific Home Manager profiles.
      output = {};
    };
  };
}
