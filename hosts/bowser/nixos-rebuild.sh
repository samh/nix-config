#!/usr/bin/env bash
# Rebuild remotely. Use like 'nixos-rebuild', e.g. 'goomba/rebuild.sh switch'.
set -euo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
DEFAULT_TARGET=bowser
#DEFAULT_TARGET=192.168.101.40
export DEFAULT_TARGET
"${DIR}"/../../scripts/remote-nixos-rebuild.sh "$@"
