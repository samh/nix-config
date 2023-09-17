#!/usr/bin/env bash
# Rebuild remotely. Use like 'nixos-rebuild', e.g. 'yoshi/rebuild.sh switch'.
set -euo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
TARGET=yoshi
#nixos-rebuild --flake .#${FLAKE_NAME} --target-host $TARGET --build-host $TARGET --use-remote-sudo "$@"

set -x
"$DIR"/sync.sh
# "-t" is needed to allocate a tty, so that sudo can ask for a password.
ssh -t "$TARGET" sudo nixos-rebuild --flake ~/nixos-sync "$@"