#!/usr/bin/env bash
# Rebuild remotely. Use like 'nixos-rebuild', e.g. 'goomba/rebuild.sh switch'.
set -euo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DEFAULT_TARGET=goomba # name is defined in ~/.ssh/config
export DEFAULT_TARGET
"${DIR}"/../../scripts/remote-nixos-rebuild.sh "$@"
