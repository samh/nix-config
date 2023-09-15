#!/usr/bin/env bash
set -xeuo pipefail
sudo nixos-rebuild --flake .#desktop-z390-9700k "$@"
