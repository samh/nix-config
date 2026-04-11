#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/rebuild-host.sh [host] [action] [extra nixos-rebuild args...]

Rebuild a remote NixOS host defined in flake.nix.

Examples:
  scripts/rebuild-host.sh
  scripts/rebuild-host.sh yoshi
  scripts/rebuild-host.sh yoshi switch
  scripts/rebuild-host.sh kirby boot --show-trace

If host and/or action are omitted and stdin is interactive, the script will
prompt for them. Common actions are:
  switch
  boot

Options:
  -h, --help    Show this help message
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

cd "$REPO_ROOT"

if [[ ! -f flake.nix ]]; then
  echo "flake.nix not found in $REPO_ROOT" >&2
  exit 1
fi

get_hosts_from_eval() {
  local output
  if ! command -v nix >/dev/null 2>&1; then
    return 1
  fi

  if output="$(nix eval --raw .#nixosConfigurations --apply 'cfgs: builtins.concatStringsSep "\n" (builtins.attrNames cfgs)' 2>/dev/null)"; then
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output"
      return 0
    fi
  fi

  return 1
}

get_hosts_from_flake_file() {
  awk '
    function count_char(str, ch,   i, c) {
      c = 0
      for (i = 1; i <= length(str); i++) {
        if (substr(str, i, 1) == ch) {
          c++
        }
      }
      return c
    }

    /^[[:space:]]*nixosConfigurations[[:space:]]*=[[:space:]]*{/ {
      in_block = 1
      depth = 1
      next
    }
    in_block {
      if (depth == 1 && match($0, /^[[:space:]]*([A-Za-z0-9._+-]+)[[:space:]]*=[[:space:]]*nixpkgs\.lib\.nixosSystem[[:space:]]*{/, m)) {
        print m[1]
      }

      depth += count_char($0, "{")
      depth -= count_char($0, "}")

      if (depth <= 0) {
        exit
      }
    }
  ' flake.nix
}

is_valid_action() {
  case "$1" in
    switch|boot|test|dry-build|build|build-vm|build-vm-with-bootloader|edit|dry-activate)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

prompt_for_host() {
  local index=1

  echo "Select host:" >&2
  for host_name in "${all_hosts[@]}"; do
    printf '  %d) %s\n' "$index" "$host_name" >&2
    ((index += 1))
  done

  while true; do
    read -r -p "Host number: " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#all_hosts[@]} )); then
      printf '%s\n' "${all_hosts[selection - 1]}"
      return 0
    fi
    echo "Please enter a number between 1 and ${#all_hosts[@]}." >&2
  done
}

prompt_for_action() {
  local actions=("switch" "boot")
  local index=1

  echo "Select action:" >&2
  for action_name in "${actions[@]}"; do
    printf '  %d) %s\n' "$index" "$action_name" >&2
    ((index += 1))
  done

  while true; do
    read -r -p "Action number: " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#actions[@]} )); then
      printf '%s\n' "${actions[selection - 1]}"
      return 0
    fi
    echo "Please enter 1 or 2." >&2
  done
}

host_arg="${1:-}"
action_arg="${2:-}"

case "$host_arg" in
  -h|--help)
    usage
    exit 0
    ;;
esac

all_hosts_raw=""
if ! all_hosts_raw="$(get_hosts_from_eval)"; then
  all_hosts_raw="$(get_hosts_from_flake_file || true)"
fi

if [[ -z "$all_hosts_raw" ]]; then
  echo "No hosts found in nixosConfigurations." >&2
  exit 1
fi

mapfile -t all_hosts < <(printf '%s\n' "$all_hosts_raw" | sed '/^[[:space:]]*$/d' | sort -u)

if [[ ${#all_hosts[@]} -eq 0 ]]; then
  echo "No hosts found in nixosConfigurations." >&2
  exit 1
fi

declare -A host_set=()
for host_name in "${all_hosts[@]}"; do
  host_set["$host_name"]=1
done

selected_host="$host_arg"
if [[ -z "$selected_host" ]]; then
  if [[ -t 0 ]]; then
    selected_host="$(prompt_for_host)"
  else
    echo "Host is required when stdin is not interactive." >&2
    usage >&2
    exit 1
  fi
fi

if [[ -z "${host_set[$selected_host]:-}" ]]; then
  echo "Unknown host: $selected_host" >&2
  echo "Valid hosts: ${all_hosts[*]}" >&2
  exit 1
fi

selected_action="$action_arg"
if [[ -z "$selected_action" ]]; then
  if [[ -t 0 ]]; then
    selected_action="$(prompt_for_action)"
  else
    echo "Action is required when stdin is not interactive." >&2
    usage >&2
    exit 1
  fi
fi

if ! is_valid_action "$selected_action"; then
  echo "Unknown or unsupported action: $selected_action" >&2
  echo "Supported actions: switch boot test dry-build build build-vm build-vm-with-bootloader edit dry-activate" >&2
  exit 1
fi

extra_args=()
if [[ $# -gt 2 ]]; then
  extra_args=("${@:3}")
fi

echo "Rebuilding ${selected_host} with action '${selected_action}'..."

TARGET="$selected_host" "${SCRIPT_DIR}/remote-nixos-rebuild.sh" "$selected_action" "${extra_args[@]}"
