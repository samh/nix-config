#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/check-host-updates.sh [options]

Check NixOS release version and last system generation update time for each
host defined in flake.nix, in parallel over SSH.

Options:
  --parallel N    Max concurrent SSH checks (default: 8)
  --timeout SEC   SSH connect timeout in seconds (default: 4)
  --hosts CSV     Check only these comma-separated hostnames
  --strict        Exit non-zero if any host is needs-update or unreachable
  -h, --help      Show this help message
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"

parallel=8
timeout=4
strict=0
hosts_csv=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parallel)
      parallel="$2"
      shift 2
      ;;
    --timeout)
      timeout="$2"
      shift 2
      ;;
    --hosts)
      hosts_csv="$2"
      shift 2
      ;;
    --strict)
      strict=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! [[ "$parallel" =~ ^[0-9]+$ ]] || (( parallel < 1 )); then
  echo "--parallel must be a positive integer" >&2
  exit 1
fi

if ! [[ "$timeout" =~ ^[0-9]+$ ]] || (( timeout < 1 )); then
  echo "--timeout must be a positive integer" >&2
  exit 1
fi

cd "$REPO_ROOT"

if [[ ! -f flake.nix ]]; then
  echo "flake.nix not found in $REPO_ROOT" >&2
  exit 1
fi

get_expected_release_from_eval() {
  local ref
  if ! command -v nix >/dev/null 2>&1; then
    return 1
  fi

  if ref="$(nix eval --raw .#inputs.nixpkgs.original.ref 2>/dev/null)"; then
    if [[ "$ref" =~ ^nixos-([0-9]{2}\.[0-9]{2})$ ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  fi

  return 1
}

get_expected_release_from_flake_file() {
  local line
  line="$(grep -E '^[[:space:]]*nixpkgs\.url[[:space:]]*=' flake.nix | head -n1 || true)"
  if [[ -n "$line" ]] && [[ "$line" =~ nixos-([0-9]{2}\.[0-9]{2}) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

get_hosts_from_eval() {
  local output
  if ! command -v nix >/dev/null 2>&1; then
    return 1
  fi

  # Output one hostname per line.
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

expected_release=""
if ! expected_release="$(get_expected_release_from_eval)"; then
  if ! expected_release="$(get_expected_release_from_flake_file)"; then
    echo "Failed to determine expected release from flake (expected nixos-XX.YY)." >&2
    exit 1
  fi
fi

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

declare -a hosts=()
if [[ -n "$hosts_csv" ]]; then
  IFS=',' read -r -a requested_hosts <<< "$hosts_csv"
  declare -A host_set=()
  for h in "${all_hosts[@]}"; do
    host_set["$h"]=1
  done

  for h in "${requested_hosts[@]}"; do
    h="${h//[[:space:]]/}"
    [[ -z "$h" ]] && continue
    if [[ -z "${host_set[$h]:-}" ]]; then
      echo "Unknown host in --hosts: $h" >&2
      exit 1
    fi
    hosts+=("$h")
  done
else
  hosts=("${all_hosts[@]}")
fi

if [[ ${#hosts[@]} -eq 0 ]]; then
  echo "No hosts to check." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

check_one_host() {
  local host="$1"
  local out_file="$2"
  local ssh_output
  local rc
  local version
  local last_update

  rc=0
  ssh_output="$({
    ssh \
      -o BatchMode=yes \
      -o ConnectTimeout="$timeout" \
      -o ConnectionAttempts=1 \
      -o StrictHostKeyChecking=accept-new \
      "$host" \
      'bash -s' <<'REMOTE'
set -euo pipefail

version="unknown"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  version="${VERSION_ID:-unknown}"
fi

# Non-login shells can miss NixOS user PATH entries.
export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:${PATH}"

last_update="unknown"

# Best signal for "last update": when the system profile symlink was switched.
if link_ts="$(stat -c '%y' /nix/var/nix/profiles/system 2>/dev/null)"; then
  # Drop sub-seconds/timezone for a compact table value.
  last_update="${link_ts%%.*}"
fi

# Fallback if profile stat isn't available for any reason.
if [[ "$last_update" == "unknown" ]]; then
  last_line="$(nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -n1 || true)"
  parsed="$(printf '%s\n' "$last_line" | awk 'NF >= 3 { print $2 " " $3 }')"
  if [[ -n "$parsed" ]]; then
    last_update="$parsed"
  fi
fi

printf '%s\t%s\n' "$version" "$last_update"
REMOTE
  } 2>/dev/null)" || rc=$?

  if (( rc != 0 )); then
    printf '%s\tunreachable\tn/a\tn/a\n' "$host" >"$out_file"
    return 0
  fi

  ssh_output="$(printf '%s' "$ssh_output" | head -n1)"

  if [[ "$ssh_output" == *$'\t'* ]]; then
    version="${ssh_output%%$'\t'*}"
    last_update="${ssh_output#*$'\t'}"
  else
    version="unknown"
    last_update="unknown"
  fi

  if [[ "$version" == "$expected_release" ]]; then
    printf '%s\tup-to-date\t%s\t%s\n' "$host" "$version" "$last_update" >"$out_file"
  else
    printf '%s\tneeds-update\t%s\t%s\n' "$host" "$version" "$last_update" >"$out_file"
  fi
}

running=0
idx=0
for host in "${hosts[@]}"; do
  out_file="$tmpdir/${idx}.tsv"
  check_one_host "$host" "$out_file" &
  idx=$((idx + 1))
  running=$((running + 1))

  if (( running >= parallel )); then
    wait -n
    running=$((running - 1))
  fi
done
wait

sorted_file="$tmpdir/sorted.tsv"
: > "$sorted_file"

up_to_date=0
needs_update=0
unreachable=0

status_rank() {
  case "$1" in
    up-to-date) printf '1' ;;
    needs-update) printf '2' ;;
    unreachable) printf '3' ;;
    *) printf '9' ;;
  esac
}

for result_file in "$tmpdir"/*.tsv; do
  [[ "$result_file" == "$sorted_file" ]] && continue
  [[ ! -f "$result_file" ]] && continue

  IFS=$'\t' read -r host status version last_update < "$result_file"
  rank="$(status_rank "$status")"
  printf '%s\t%s\t%s\t%s\t%s\n' "$rank" "$host" "$status" "$version" "$last_update" >> "$sorted_file"

  case "$status" in
    up-to-date) up_to_date=$((up_to_date + 1)) ;;
    needs-update) needs_update=$((needs_update + 1)) ;;
    unreachable) unreachable=$((unreachable + 1)) ;;
  esac
done

if [[ ! -s "$sorted_file" ]]; then
  echo "No results collected." >&2
  exit 1
fi

sorted_rows="$tmpdir/sorted-rows.tsv"
sort -t $'\t' -k1,1n -k2,2 "$sorted_file" > "$sorted_rows"

host_w=4
status_w=6
version_w=7
update_w=11

while IFS=$'\t' read -r _ host status version last_update; do
  (( ${#host} > host_w )) && host_w=${#host}
  (( ${#status} > status_w )) && status_w=${#status}
  (( ${#version} > version_w )) && version_w=${#version}
  (( ${#last_update} > update_w )) && update_w=${#last_update}
done < "$sorted_rows"

printf 'Expected release: %s\n\n' "$expected_release"
printf "%-${host_w}s  %-${status_w}s  %-${version_w}s  %-${update_w}s\n" "HOST" "STATUS" "VERSION" "LAST_UPDATE"
printf "%-${host_w}s  %-${status_w}s  %-${version_w}s  %-${update_w}s\n" \
  "$(printf '%*s' "$host_w" '' | tr ' ' '-')" \
  "$(printf '%*s' "$status_w" '' | tr ' ' '-')" \
  "$(printf '%*s' "$version_w" '' | tr ' ' '-')" \
  "$(printf '%*s' "$update_w" '' | tr ' ' '-')"

while IFS=$'\t' read -r _ host status version last_update; do
  printf "%-${host_w}s  %-${status_w}s  %-${version_w}s  %-${update_w}s\n" \
    "$host" "$status" "$version" "$last_update"
done < "$sorted_rows"

printf '\nSummary:\n'
printf '  up-to-date: %d\n' "$up_to_date"
printf '  needs-update: %d\n' "$needs_update"
printf '  unreachable: %d\n' "$unreachable"

if (( strict == 1 )) && (( needs_update > 0 || unreachable > 0 )); then
  exit 1
fi
