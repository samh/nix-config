{
  config,
  lib,
  pkgs,
  ...
}: let
  # Mirrors Syncthing notes into local git repos and auto-pushes to Gitea.
  # Keeps .git outside Syncthing-managed directories to avoid repo corruption.
  historyRoot = "/var/lib/notes-history";
  deployKeySecret = "notes-history-gitea-deploy-key";
  gitIdentityName = "Notes History Bot";
  gitIdentityEmail = "notes-history@${config.my.hostDomain}";
  defaultBranch = "main";
  giteaSshHost = "gitea.${config.my.hostDomain}";

  repos = {
    notes-shared = {
      src = "${config.my.homeDir}/Notes/Notes-Shared";
      dst = "${historyRoot}/notes-shared";
      remote = "gitea@${giteaSshHost}:${config.my.user}/notes-shared.git";
    };
    notes-personal = {
      src = "${config.my.homeDir}/Notes/Notes-Personal";
      dst = "${historyRoot}/notes-personal";
      remote = "gitea@${giteaSshHost}:${config.my.user}/notes-personal.git";
    };
  };

  mkService = name: repo: {
    description = "Record and push history for ${name}";
    after = ["syncthing.service" "gitea.service" "network-online.target"];
    wants = ["network-online.target"];
    path = with pkgs; [coreutils git openssh rsync util-linux];
    serviceConfig = {
      Type = "oneshot";
      User = config.my.user;
      Group = "users";
      Environment = "HOME=${config.my.homeDir}";
      # Only needs read access to source notes and write access to history repos.
      ReadWritePaths = [
        historyRoot
      ];
    };
    script = ''
      set -euo pipefail

      src=${lib.escapeShellArg repo.src}
      dst=${lib.escapeShellArg repo.dst}
      remote=${lib.escapeShellArg repo.remote}
      branch=${lib.escapeShellArg defaultBranch}
      key=${lib.escapeShellArg config.sops.secrets.${deployKeySecret}.path}

      [ -d "$src" ] || exit 0
      mkdir -p "$dst"

      exec 9>"$dst/.history.lock"
      flock -n 9 || exit 0

      if [ ! -d "$dst/.git" ]; then
        git init -b "$branch" "$dst"
        git -C "$dst" config user.name ${lib.escapeShellArg gitIdentityName}
        git -C "$dst" config user.email ${lib.escapeShellArg gitIdentityEmail}
      fi

      rsync -a --delete \
        --exclude ".git/" \
        --exclude ".stfolder" \
        --exclude ".stignore" \
        --exclude ".stversions" \
        --exclude "*.sync-conflict-*" \
        "$src"/ "$dst"/

      current_remote="$(git -C "$dst" remote get-url origin 2>/dev/null || true)"
      if [ -z "$current_remote" ]; then
        git -C "$dst" remote add origin "$remote"
      elif [ "$current_remote" != "$remote" ]; then
        git -C "$dst" remote set-url origin "$remote"
      fi

      git -C "$dst" add -A
      if ! git -C "$dst" diff --cached --quiet; then
        timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        git -C "$dst" -c commit.gpgSign=false commit -m "notes(${name}): $timestamp"
      fi

      # Always attempt push so prior failed pushes are retried even with no
      # new file changes.
      GIT_SSH_COMMAND="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
        git -C "$dst" push -u origin "$branch"
    '';
  };

  mkTimer = name: {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "3m";
      OnUnitActiveSec = "10m";
      RandomizedDelaySec = "120s";
      Persistent = true;
      Unit = "notes-history-${name}.service";
    };
  };
in {
  sops.secrets.${deployKeySecret} = {
    owner = config.my.user;
    group = "users";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d ${historyRoot} 0750 ${config.my.user} users - -"
  ];

  systemd.services = lib.mapAttrs' (n: r: lib.nameValuePair "notes-history-${n}" (mkService n r)) repos;
  systemd.timers = lib.mapAttrs' (n: _: lib.nameValuePair "notes-history-${n}" (mkTimer n)) repos;
}
