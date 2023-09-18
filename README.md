# NixOS Configurations

## Quick Reference
- Update `flake.lock` and commit: `nix flake update --commit-lock-file`
- Rebuild a host: `sudo nixos-rebuild boot` (or `switch`)

## Initial Setup
To make this the default configuration for a machine, make a symbolic link
from the flake to `/etc/nixos`:

```shell
ln -s $(pwd)/flake.nix /etc/nixos/
```

### Non-Declarative Configuration
- Tailscale: `sudo tailscale up [options...]`

## nixos-rebuild
Since `nixos-rebuild` defaults to the flake pointed at by a symbolic link at
`/etc/nixos/flake.nix` and the configuration matching the hostname, we should
normally be able to do a rebuild with the usual command, for example:

```shell
sudo nixos-rebuild boot
# or switch, etc.
```

### Remote Builds
I haven't found a remote management solution that I like yet, so I'm using
plain `ssh` for now with a simple wrapper script:

```shell
./hosts/yoshi/nixos-rebuild.sh boot
```

## Source Layout

Each machine has its own subdirectory, which is included from the main
`flake.nix`.

Shared modules are stored under the `include` subdirectory
(for lack of a better name).
