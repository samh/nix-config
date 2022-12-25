# NixOS Configurations
This directory is normally checked out directly into `/etc/nixos`.
Each machine has its own subdirectory, then the files are linked
to the top level; for example:

```bash
ln -s framework/configuration.nix .
ln -s framework/hardware-configuration.nix .
```

Shared modules are stored under the `include` subdirectory
(for lack of a better name).
