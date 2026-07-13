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
  shortcuts.

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

No output layout is configured yet. Sway uses detected defaults so the
configuration does not guess connector names, resolutions, positions, scale,
or rotation.

Inspect active outputs from a running Sway session with:

```shell
swaymsg -t get_outputs
```

Add verified settings to `wayland.windowManager.sway.config.output` in
`home-manager/global/sway.nix`, then update this document with the resulting
layout.

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
