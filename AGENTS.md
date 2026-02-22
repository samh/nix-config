# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` is the entrypoint. It defines `nixosConfigurations`, `homeConfigurations`, overlays, packages, and shared modules.
- `hosts/<hostname>/` contains machine-specific NixOS configs and host notes (for example `hosts/kirby/README.md`).
- `home-manager/` holds Home Manager profiles (`generic.nix` plus host-specific files).
- `include/` contains shared Nix modules used across hosts; `modules/nixos` and `modules/home-manager` export reusable module sets.
- `scripts/` contains operational helpers (for example `check-host-updates.sh`, `remote-nixos-rebuild.sh`).
- `secrets/` and `.sops.yaml` are for encrypted secret management with `sops`.

## Build, Test, and Development Commands
- `nix flake check --no-build` (or `just check` / `doit check`): validate flake outputs without building.
- `nix flake update --commit-lock-file` (or `just up` / `doit up`): update `flake.lock` and commit the lock change.
- `nix fmt`: format Nix codebase using the flake formatter (`alejandra`).
- `just check-host-updates` or `scripts/check-host-updates.sh --strict`: verify remote hosts are reachable and on expected release.
- Local apply flow: `nh os boot -a` (or `switch`) and `nh home switch -a .`.

## Coding Style & Naming Conventions
- Nix is the primary language; use 2-space indentation and keep attribute sets readable.
- Run `nix fmt` before committing. Pre-commit also enforces whitespace/YAML checks and runs `alejandra` on `*.nix`.
- Shell scripts should be Bash with strict mode (`set -euo pipefail`) and descriptive function names.
- Name host directories/config keys consistently with hostnames (for example `hosts/lakitu`, `nixosConfigurations.lakitu`).

## Testing Guidelines
- There is no dedicated unit-test suite in this repo today; validation is command-based.
- Minimum check before PR: `nix flake check --no-build`.
- For infra/host changes, also run `scripts/check-host-updates.sh --strict` when relevant.
- If adding scripts, include simple argument validation and usage output (`-h/--help`), following existing patterns.

## Commit & Pull Request Guidelines
- Follow existing commit style: `<scope>: <imperative summary>` (examples: `lakitu: migrate options for NixOS 25.11`, `desktop: add python packages`).
- Keep lockfile-only updates isolated (`flake.lock: Update`).
- PRs should state affected hosts/modules, user-visible impact, commands run for validation, and any manual follow-up steps (rebuild/switch, secret rotation, etc.).

## Security & Configuration Tips
- Never commit plaintext secrets. Use `sops secrets/secrets.yaml` (`just secrets-edit`) and keep `.sops.yaml` recipients current.
