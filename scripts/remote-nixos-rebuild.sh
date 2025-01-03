#!/usr/bin/env bash
# Rebuild remotely. Use like 'nixos-rebuild'.
# Intended to be called from other scripts, e.g. 'yoshi/rebuild.sh switch'.
set -euo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Use TARGET if it is set, otherwise use DEFAULT_TARGET.
# Error if neither is set.
TARGET=${TARGET:-${DEFAULT_TARGET:?TARGET or DEFAULT_TARGET must be set}}
export TARGET

# Check for at least one argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <nixos-rebuild arguments>"
    echo
    echo "Example: ./nixos-rebuild.sh switch"
    echo
    # Prompt y/n if the user wants to just sync
    read -p "Would you like to run sync? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$DIR"/sync.sh
        exit $?
    else
        echo "Exiting..."
        exit 1
    fi
fi

#nixos-rebuild --flake .#${FLAKE_NAME} --target-host $TARGET --build-host $TARGET --use-remote-sudo "$@"

set -x
"$DIR"/sync.sh
# "-t" is needed to allocate a tty, so that sudo can ask for a password.
#ssh -t "$TARGET" sudo nixos-rebuild --flake ~/nixos-sync "$@"
# Call the script (part of the synced files) on the target machine.
ssh -t "$TARGET" bash ~/nixos-sync/scripts/.rebuild.sh "$@"
