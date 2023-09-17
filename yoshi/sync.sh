#!/usr/bin/env bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"/..

# rsync to ~/nixos-sync on the remote host 'yoshi'
rsync -avHX --delete ./ yoshi:nixos-sync/
