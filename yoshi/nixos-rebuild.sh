#!/usr/bin/env bash
# Rebuild remotely. Use like 'nixos-rebuild', e.g. 'yoshi/rebuild.sh switch'.
set -xeuo pipefail
FLAKE_NAME=yoshi
TARGET=samh@yoshi
nixos-rebuild --flake .#${FLAKE_NAME} --target-host $TARGET --build-host $TARGET --use-remote-sudo "$@"
