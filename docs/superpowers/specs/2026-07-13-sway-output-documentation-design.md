# Sway Output Documentation Design

## Goal

Expand `docs/sway.md` with a practical monitor-configuration workflow for the
desktop's LG UltraGear and HP Z27n G2 displays. Cover both temporary changes in
a running Sway session and persistent settings in Home Manager.

## Verified Layout

- `DP-2` is the HP Z27n G2. Run it at `2560x1440@59.951Hz`, rotate it 90
  degrees counter-clockwise with transform `270`, and place it at position
  `0 0`.
- `HDMI-A-3` is the LG UltraGear. Run it at `2560x1440@59.951Hz` with normal
  rotation and place it at position `1440 560`.

After rotation, the HP occupies 1440 by 2560 logical pixels. The LG's
560-pixel vertical offset centers its 1440-pixel height against the HP's
2560-pixel height.

## Documentation Changes

Replace the current unconfigured-output note in `docs/sway.md` with:

1. Commands for inspecting output names, supported modes, and active geometry.
2. One `swaymsg` command that applies the verified two-monitor layout live.
3. A reset example using preferred modes, automatic positions, and normal
   transforms so an experimental layout is easy to undo.
4. The equivalent `wayland.windowManager.sway.config.output` Nix attribute set
   for persistent configuration.
5. Short explanations of mode, position, transform, logical dimensions, and
   applying Home Manager changes.

## Scope and Verification

This change edits documentation only; it does not enable the persistent output
block in `home-manager/global/sway.nix`. Verify command syntax against the
running Sway session, review Markdown rendering and line lengths, and run the
repository's lightweight flake evaluation because the documented Nix example
must use valid Home Manager option syntax.
