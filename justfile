# Show all available recipes when `just` is run with no args.
default:
  @just --list

# Run checks against the flake without building.
check:
  nix flake check --no-build

# Update `flake.lock` and commit.
up:
  nix flake update --commit-lock-file

# Update only the llm-agents flake input.
update-llm-agents:
  nix flake update llm-agents

# Update the VS Code extensions flake
update-vscode:
  nix flake update nix-vscode-extensions

# Short alias for update-llm-agents.
up-llm:
  @just update-llm-agents

# Run host update check.
check-host-updates:
  scripts/check-host-updates.sh
