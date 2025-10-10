# NixOS Configurations

## Quick Reference
- Update `flake.lock` and commit: `nix flake update --commit-lock-file`
  - Shortcut: `doit up`
- Run a check: `nix flake check --no-build`
  - Shortcut: `doit check`
- Rebuild the local host:
  - `nh os boot -a` (or `switch`)
  - `nh home switch -a .`
  - Without `nh`:
    - `sudo nixos-rebuild boot` (or `switch`)
    - `home-manager switch`
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
  - `sudo tailscale up --accept-routes` (to enable subnet routes)
  - `--accept-dns=false` (to disable MagicDNS)
    - I've had some issues with it; also local Blocky DNS automatically forwards
      Tailnet queries to Tailscale DNS
    - To disable later: `sudo tailscale set --accept-dns=false`
- Wireless networks (could be declared; see for example
  <https://github.com/Misterio77/nix-config/blob/main/hosts/common/optional/wireless.nix>)

#### Secrets
*I'm working on switching to `sops-nix` for secrets management; see hosts/goomba.*

- See `.sops.yaml` for a quick reference on adding hosts/keys
- `/root/.ssh/id_ed25519.pub` - root's SSH key
  - `ssh-keygen -t ed25519`
  - Needs to be added to BorgBase
- `/root` - used for secrets that should only be
  readable by the root user, since only root can read it by default.
  - Borg passphrases for each repo
    - `/root/borg-pass` (default)
  - `/root/borgmatic.env`:
    - `HEALTHCHECKS_URL=https://hc-ping.com/...`
    - Or just `touch /root/borgmatic.env` if not needed
  - Credentials for mounting Samba shares:
    ```
    root@nixos-2022-desktop ~# cat /root/smb-secrets
    username=samh
    password=password-here
    ```

#### Backups
- BorgBase - repos need to be initialized
  - `sudo borgmatic init -e repokey-blake2`

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
plain `ssh` for now with a simple wrapper script, which runs from each
machine's subdirectory:

```shell
./hosts/yoshi/nixos-rebuild.sh boot
```

This has the advantage of being able to use `nh` to get nice-looking output.

## Source Layout

Each machine has its own subdirectory, which is included from the main
`flake.nix`.

Shared modules are stored under the `include` subdirectory
(for lack of a better name).

### Things Specific to This Repo
- `options.my` / `config.my` refers to my personal configurations
  (i.e. things that are locally defined, local to the repo)

## home-manager

If `flake.nix` is linked into the right place as shown in the initial setup,
then we should be able to call `home-manager` without specifying the
flake explicitly:

```shell
home-manager switch
```
