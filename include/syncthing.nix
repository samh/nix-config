# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  pkgs,
  ...
}: let
  # Include all known Syncthing devices from metadata so the helper script
  # can resolve IDs in either short or full form.
  syncthingHosts = lib.filterAttrs (_: value: value ? syncthing_id) config.my.metadata.hosts;
  syncthingHostRows = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "${name}|${value.syncthing_id}") syncthingHosts
  );
in {
  imports = [
    ./metadata.nix
  ];

  config = {
    services.syncthing = {
      enable = true;
      user = "${config.my.user}";
      # Default folder for new synced folders
      dataDir = "${config.my.homeDir}/Documents";
      # Folder for Syncthing's settings and keys
      configDir = "${config.my.homeDir}/.config/syncthing";
      # Whether to open the default ports in the firewall: TCP/UDP 22000 for transfers and UDP 21027 for discovery.
      openDefaultPorts = true;

      overrideDevices = true; # overrides any devices added or deleted through the WebUI
      overrideFolders = true; # overrides any folders added or deleted through the WebUI

      settings = {
        # By default, include all hosts in metadata, which have a syncthing_id,
        # but excluding the current host.
        # Would be nice to also add "addresses" if available (local and tailscale).
        devices =
          # mapAttrs outputs a mapping, keeping the name as-is; the value is what
          # gets modified - in this case the output is an attribute set (map).
          builtins.mapAttrs (name: value: {
            id = value.syncthing_id;
          })
          # Filter out all the hosts without a syncthing_id,
          # and filter out the current host.
          (lib.filterAttrs (n: v: (v ? syncthing_id) && (n != config.networking.hostName))
            config.my.metadata.hosts);
      };
    };

    environment.systemPackages = [
      # `syncthing-id` helps decode Syncthing conflict filenames (which use a
      # short device ID like ME2B765) back to the friendly host alias from
      # metadata.toml (for example `work-laptop`).
      (pkgs.writeShellScriptBin "syncthing-id" ''
                set -euo pipefail

                usage() {
                  cat <<'EOF'
        Usage:
          syncthing-id                  List all known Syncthing device IDs
          syncthing-id QUERY [QUERY...] Resolve one or more IDs or conflict filenames

        Accepted QUERY forms:
          - Short device ID prefix: ME2B765
          - Full Syncthing ID:      ME2B765-2HQWLAO-...
          - Conflict path/name:     foo.sync-conflict-YYYYMMDD-HHMMSS-ME2B765.md

        Options:
          -h, --help                 Show this help
        EOF
                }

                device_rows() {
                  cat <<'EOF'
        ${syncthingHostRows}
        EOF
                }

                print_all_devices() {
                  printf '%-18s %-8s %s\n' "HOST" "SHORTID" "FULL-ID"
                  while IFS='|' read -r host full_id; do
                    [ -n "$host" ] || continue
                    short_id="''${full_id%%-*}"
                    printf '%-18s %-8s %s\n' "$host" "$short_id" "$full_id"
                  done < <(device_rows)
                }

                lookup_one() {
                  local query raw_upper base_upper stem_upper
                  local candidate candidate_clean candidate_compact
                  local host full_id full_upper full_compact short_id
                  local key
                  local -a candidates matches
                  local -A seen

                  query="$1"
                  raw_upper="$(printf '%s' "$query" | tr '[:lower:]' '[:upper:]')"
                  base_upper="''${raw_upper##*/}"
                  stem_upper="''${base_upper%%.*}"
                  candidates=("$raw_upper" "$base_upper" "$stem_upper")
                  matches=()
                  seen=()

                  if [[ "$raw_upper" =~ SYNC-CONFLICT-[0-9]{8}-[0-9]{6}-([A-Z0-9]{7}) ]]; then
                    candidates+=("''${BASH_REMATCH[1]}")
                  fi

                  while IFS= read -r candidate; do
                    [ -n "$candidate" ] || continue
                    candidates+=("$candidate")
                  done < <(printf '%s\n' "$raw_upper" | grep -oE '[A-Z0-9]{7}' | sort -u || true)

                  while IFS='|' read -r host full_id; do
                    [ -n "$host" ] || continue
                    full_upper="$(printf '%s' "$full_id" | tr '[:lower:]' '[:upper:]')"
                    full_compact="''${full_upper//-/}"
                    short_id="''${full_upper%%-*}"

                    for candidate in "''${candidates[@]}"; do
                      candidate_clean="$(printf '%s' "$candidate" | tr -cd 'A-Z0-9-')"
                      [ -n "$candidate_clean" ] || continue
                      candidate_compact="''${candidate_clean//-/}"

                      if [ "$candidate_clean" = "$full_upper" ] || [ "$candidate_clean" = "$short_id" ] || [ "$candidate_compact" = "$full_compact" ]; then
                        key="$host|$full_id"
                        if [ -z "''${seen[$key]:-}" ]; then
                          matches+=("$key")
                          seen[$key]=1
                        fi
                      fi
                    done
                  done < <(device_rows)

                  if [ "''${#matches[@]}" -eq 0 ]; then
                    printf '%s -> no Syncthing device match\n' "$query" >&2
                    return 1
                  fi

                  if [ "''${#matches[@]}" -gt 1 ]; then
                    printf '%s -> multiple matches:\n' "$query" >&2
                    for key in "''${matches[@]}"; do
                      IFS='|' read -r host full_id <<<"$key"
                      printf '  %s (%s)\n' "$host" "$full_id" >&2
                    done
                    return 1
                  fi

                  IFS='|' read -r host full_id <<<"''${matches[0]}"
                  printf '%s -> %s (%s)\n' "$query" "$host" "$full_id"
                }

                if [ "$#" -eq 0 ]; then
                  print_all_devices
                  exit 0
                fi

                case "$1" in
                  -h|--help)
                    usage
                    exit 0
                    ;;
                esac

                rc=0
                for arg in "$@"; do
                  if ! lookup_one "$arg"; then
                    rc=1
                  fi
                done
                exit "$rc"
      '')
    ];
  };
}
