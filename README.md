# NixOS Configurations

## Quick Reference
- Update `flake.lock` and commit: `nix flake update --commit-lock-file`
- Rebuild a host: `sudo nixos-rebuild boot` (or `switch`)
- Auto-format: `nix fmt`

## Initial Setup
To make this the default configuration for a machine, make a symbolic link
from the flake to `/etc/nixos`:

```shell
ln -s $(pwd)/flake.nix /etc/nixos/
# for remote machines:
ln -s /home/samh/nixos-sync/flake.nix /etc/nixos/flake.nix
```

It looks like you should be able to do the same for Home Manager:

```shell
mkdir -p ~/.config/home-manager
ln -s $(pwd)/flake.nix ~/.config/home-manager/
```


### Non-Declarative Configuration
*Things that are not included in the Nix configuration*

- User password
- Tailscale: `sudo tailscale up [options...]`
- Wireless networks (could be declared; see for example
  <https://github.com/Misterio77/nix-config/blob/main/hosts/common/optional/wireless.nix>)

#### Secrets
- `/root/.ssh/id_ed25519.pub` - root's SSH key
  - `ssh-keygen -t ed25519`
  - Needs to be added to BorgBase
- `/root` - used for secrets that should only be
  readable by the root user, since only root can read it by default.
  - Borg passphrases for each repo
    - `/root/borg-pass` (default)
  - `/root/borgmatic.env`:
    - `HEALTHCHECKS_URL=https://hc-ping.com/...`
  - `/root/acme.env` - secrets for ACME certificates (Let's Encrypt)

#### Backups
- BorgBase - repos need to be initialized
  - `borgmatic init -e repokey-blake2`

#### Service State
- Usually stored under `/var/lib` for each service
  - In particular, the systemd option `StateDirectory` creates a directory
    under `/var/lib` for the service
  - When `DynamicUser=true`, it will be under `/var/lib/private` with a
    symbolic link under `/var/lib`.

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

### Things Specific to This Repo
- `options.my` / `config.my` refers to my personal configurations
  (i.e. things that are locally defined, local to the repo)
