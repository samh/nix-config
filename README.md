# NixOS Configurations

Each machine has its own subdirectory, which is included from the main
`flake.nix`. Each machine has a rebuild script, for example:
```bash
cd framework
./rebuild.sh switch --upgrade
```

Shared modules are stored under the `include` subdirectory
(for lack of a better name).
