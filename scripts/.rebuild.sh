#!/usr/bin/env bash
# This script will be run on the target machine by the remote-nixos-rebuild.sh script.
if command -v nh >/dev/null 2>&1; then
    nh os "$@" -a ~/nixos-sync
else
    sudo nixos-rebuild --flake ~/nixos-sync "$@"
fi
