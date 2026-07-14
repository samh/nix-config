# Sway Desktop Session

This repository provides Sway as a Wayland session alongside the existing
XFCE session on `nixos-2022-desktop`. LightDM remains the display manager, so
either desktop can be selected at login.

The configuration is split between:

- [`hosts/desktop-z390-9700k/configuration.nix`](../hosts/desktop-z390-9700k/configuration.nix),
  which enables the NixOS Sway module and installs system-wide companion
  programs;
- [`home-manager/global/sway.nix`](../home-manager/global/sway.nix), which
  defines the user-facing Sway configuration, startup programs, and keyboard
  shortcuts;
- [`home-manager/nixos-2022-desktop.nix`](../home-manager/nixos-2022-desktop.nix),
  which defines the host-specific monitor layout.

Although the Home Manager module is under `home-manager/global`, it is
currently imported only by
[`home-manager/nixos-2022-desktop.nix`](../home-manager/nixos-2022-desktop.nix).

## Programs

| Program | Purpose |
| --- | --- |
| Sway | The Wayland compositor and tiling window manager. It replaces XFWM's window-management and compositing roles; Waybar provides the panel. |
| Ghostty | The terminal opened by `Super+Enter`. It was already the preferred terminal on this host. |
| Waybar | The panel at the top or bottom of the screen. It provides workspace indicators, status information, and a system tray. |
| Fuzzel | A lightweight Wayland application launcher. Start it with `Alt+Space` or `Super+D`, type an application name, and press Enter. |
| Mako | The notification daemon. It displays desktop notifications sent by applications. |
| swaylock | The screen locker. It is used by the manual lock shortcut and by swayidle. |
| swayidle | Watches for idle and sleep events. It locks after ten minutes of inactivity and before sleep, but does not automatically suspend or turn off displays. |
| grim | Takes screenshots from a Wayland compositor. |
| slurp | Lets grim select a rectangular screen region interactively. |
| wl-clipboard | Provides `wl-copy` and `wl-paste`. The screenshot shortcuts copy PNG images to the Wayland clipboard. |
| NetworkManager applet | Provides the network status tray icon and connection menu. It is already installed by the XFCE configuration and starts in Sway through XDG autostart. |
| pavucontrol | The graphical PipeWire/PulseAudio volume mixer. It was already installed by the shared GUI sound configuration. |
| Thunar | The graphical file manager shared with XFCE. It was already enabled by the XFCE module. |
| polkit-gnome | Displays authentication prompts for privileged desktop actions. Sway starts the existing agent explicitly because its XDG autostart file is restricted to other desktops. |

The NixOS Sway module also configures the LightDM session file, Xwayland,
desktop portals, the polkit service, PAM support for swaylock, and XDG
autostart for a window-manager-only session. These are not duplicated in the
local configuration.

## Keyboard Shortcuts

`Super` is the main window-management modifier. Sway calls it `Mod4`; `Alt` is
`Mod1`.

| Shortcut | Action |
| --- | --- |
| `Super+Enter` | Open Ghostty |
| `Alt+Space` | Open Fuzzel |
| `Alt+F4` | Close the focused window |
| `Super+D` | Open Fuzzel |
| `Super+Shift+Q` | Close the focused window |
| `Super+H/J/K/L` | Move focus left/down/up/right |
| `Super+Shift+H/J/K/L` | Move the focused window left/down/up/right |
| `Super+Space` | Toggle floating for the focused window |
| `Super+1` through `Super+9` | Switch to workspace 1 through 9 |
| `Super+Shift+1` through `Super+Shift+9` | Move the focused window to workspace 1 through 9 |
| `Super+Ctrl+L` | Lock the session with swaylock |
| `Print` | Copy a screenshot of all outputs to the clipboard |
| `Shift+Print` | Select a region and copy its screenshot to the clipboard |

The Sway `Alt+Space` binding is independent of XFCE keyboard settings. XFCE
continues to use its existing `Alt+Space` Ulauncher shortcut.

LightDM starts this host's graphical session on VT 2. The host configuration
disables `getty@tty2` and its `autovt@tty2` alias so a console getty cannot
claim the same VT as Sway and interpret `Alt+F1` through `Alt+F12` as console
VT switches. Sway retains its normal `Ctrl+Alt+F1` through `Ctrl+Alt+F12` VT
switching behavior.

Apply the system-level VT fix and the user-level shortcut, then reload Sway:

```shell
nh os switch -a
nh home switch -a .
swaymsg reload
```

To save a screenshot already copied to the clipboard:

```shell
wl-paste --type image/png > screenshot.png
```

## Session Startup

Home Manager starts these processes from the generated Sway configuration:

- Waybar;
- Mako;
- the polkit-gnome authentication agent;
- swayidle.

The NixOS Sway module enables XDG autostart for the session. This starts the
existing NetworkManager applet, input-method integration, GNOME Keyring
components, and any existing per-user autostart applications. No XFCE panel,
XFCE desktop, or XFWM compositor is started inside Sway.

## GNOME Keyring and Secret Service

GNOME Keyring remains the Secret Service provider in both XFCE and Sway.
KeePassXC is installed, but this configuration does not enable its Secret
Service integration.

The existing XFCE module enables:

- `services.gnome.gnome-keyring`;
- GNOME Keyring integration in the LightDM PAM service.

At login, LightDM's PAM integration unlocks the login keyring. GNOME Keyring's
XDG autostart and D-Bus activation then make Secret Service available in Sway.
The Home Manager Sway module imports the Wayland session environment into the
host's `dbus-broker` user environment so D-Bus-activated applications see the
correct session.

If the XFCE module is ever removed, preserve the GNOME Keyring service and
LightDM PAM options explicitly rather than switching Secret Service to
KeePassXC.

## Display and GPU Configuration

Sway identifies displays by their connector names. On this desktop the
connectors and displays are:

| Connector | Display | Layout |
| --- | --- | --- |
| `DP-2` | HP Z27n G2 | Left, `2560x1440`, rotated 90 degrees counter-clockwise |
| `HDMI-A-3` | LG UltraGear | Right, `2560x1440`, normal orientation |

Connector names can change when a cable is moved to another port. Inspect the
currently connected outputs, supported modes, active mode, position, and
transform from a running Sway session with:

```shell
swaymsg -t get_outputs
```

For a shorter summary when `jq` is available:

```shell
swaymsg -t get_outputs --raw \
  | jq '.[] | {name, make, model, modes, current_mode, transform, rect}'
```

### Changing the Layout Dynamically

Use `swaymsg output` to test settings immediately without editing or applying
the Home Manager configuration. The following command places the portrait HP
on the left and vertically centers the LG on its right:

```shell
swaymsg 'output DP-2 mode 2560x1440@59.951Hz transform 270 position 0 0; output HDMI-A-3 mode 2560x1440@59.951Hz transform normal position 1440 560'
```

In Sway, transform `270` is a 270-degree clockwise rotation, which is the same
as 90 degrees counter-clockwise. Rotation changes the HP's logical dimensions
to 1440 by 2560 pixels. The LG therefore starts at X position 1440, and its Y
position is `(2560 - 1440) / 2 = 560` to center it vertically.

The important output properties are:

- `mode`: physical resolution and optional refresh rate;
- `transform`: rotation (`normal`, `90`, `180`, or `270`);
- `position`: X and Y coordinates in the combined logical desktop, measured
  from its top-left corner;
- `scale`: optional display scaling, which defaults to `1` here.

Re-run the command with different positions to experiment. Dynamic changes
last only for the current Sway session unless the same settings are added to
the persistent configuration. Run `swaymsg reload` to discard experiments and
restore the persistent layout. To return to automatic detection, first remove
the persistent output settings described below and apply the Home Manager
configuration.

### Configuring the Layout Persistently

After verifying a layout dynamically, add it to
`wayland.windowManager.sway.config.output` in
`home-manager/nixos-2022-desktop.nix`. Output connector names and physical
positions are host-specific, so they do not belong in
`home-manager/global/sway.nix`. The persistent configuration is:

```nix
output = {
  "DP-2" = {
    mode = "2560x1440@59.951Hz";
    transform = "270";
    position = "0 0";
  };
  "HDMI-A-3" = {
    mode = "2560x1440@59.951Hz";
    transform = "normal";
    position = "1440 560";
  };
};
```

Apply a persistent Home Manager change and reload the running compositor with:

```shell
nh home switch -a .
swaymsg reload
```

If Sway rejects a setting, inspect the full output data again and use one of
the modes advertised for that connector. Removing an output's attribute set
from `home-manager/nixos-2022-desktop.nix` returns that output to Sway's
detected defaults after the next configuration reload or login.

The desktop display uses the Intel GPU through the `modesetting` driver. The
NVIDIA GPU remains reserved for VFIO passthrough. Do not add NVIDIA-specific
Sway options or make the session depend on the NVIDIA GPU.

## Applying and Verifying Changes

The NixOS configuration makes the Sway session available to LightDM. The Home
Manager configuration installs the generated user configuration. Apply both
parts using the repository's normal workflows:

```shell
nh os boot -a
nh home switch -a .
```

After booting the new NixOS generation, choose **Sway** from LightDM's session
chooser before logging in. XFCE remains available as a fallback.

Format and evaluate changes with:

```shell
alejandra hosts/desktop-z390-9700k/configuration.nix home-manager/global/sway.nix
nix build --no-link '.#homeConfigurations."samh@nixos-2022-desktop".activationPackage'
nix flake check --no-build
```

When changing either Sway Nix file, update this document if the program list,
startup behavior, shortcuts, security integration, output layout, or apply
procedure changes.
