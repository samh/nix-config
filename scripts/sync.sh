#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"/../

# Use environment variables for input.
# Error if TARGET is not set.
: "${TARGET:?TARGET must be set}"

# Default to syncing to ~/nixos-sync/
: "${TARGET_PATH:=nixos-sync}"

# rsync to the remote host
rsync -avHX --delete --exclude-from="${DIR}"/exclude.txt ./ "${TARGET}:${TARGET_PATH}/" "$@"
