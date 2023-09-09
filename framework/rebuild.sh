#!/usr/bin/env bash
set -xeuo pipefail
sudo nixos-rebuild --flake .#fwnixos "$@"
