#!/usr/bin/env bash
# Rebuild remotely. Use like 'nixos-rebuild', e.g. 'kirby/rebuild.sh switch'.
set -euo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
TARGET=kirby
export TARGET
"${DIR}"/../../scripts/remote-nixos-rebuild.sh "$@"
