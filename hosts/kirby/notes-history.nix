{
  config,
  lib,
  pkgs,
  ...
}: let
  # Bidirectional sync between Syncthing-managed notes folders and Gitea.
  # Keeps git metadata outside Syncthing-managed directories.
  # Canonical docs: hosts/kirby/notes-history.md
  historyRoot = "/var/lib/notes-history";
  deployKeySecret = "notes-history-gitea-deploy-key";
  giteaApiTokenSecret = "notes-history-gitea-api-token";
  uptimeKumaPushUrlSecret = "notes-history-uptime-kuma-push-url";
  gitIdentityName = "Notes History Bot";
  gitIdentityEmail = "notes-history@${config.my.hostDomain}";
  defaultBranch = "main";
  conflictBranch = "conflict/kirby";
  giteaSshHost = "gitea.${config.my.hostDomain}";
  giteaHttpBase = "https://${giteaSshHost}";

  repos = {
    notes-shared = {
      workTree = "${config.my.homeDir}/Notes/Notes-Shared";
      gitDir = "${historyRoot}/notes-shared.git";
      remote = "gitea@${giteaSshHost}:${config.my.user}/notes-shared.git";
      owner = config.my.user;
      repoName = "notes-shared";
    };
    notes-personal = {
      workTree = "${config.my.homeDir}/Notes/Notes-Personal";
      gitDir = "${historyRoot}/notes-personal.git";
      remote = "gitea@${giteaSshHost}:${config.my.user}/notes-personal.git";
      owner = config.my.user;
      repoName = "notes-personal";
    };
  };

  mkService = name: repo: {
    description = "Bidirectional notes sync for ${name}";
    after = ["syncthing.service" "gitea.service" "network-online.target"];
    wants = ["network-online.target"];
    onFailure = ["notes-history-alert@%n.service"];
    path = with pkgs; [coreutils curl gawk git jq openssh util-linux];
    serviceConfig = {
      Type = "oneshot";
      User = config.my.user;
      Group = "users";
      Environment = "HOME=${config.my.homeDir}";
      ReadWritePaths = [
        historyRoot
        repo.workTree
      ];
    };
    script = ''
      set -euo pipefail

      work_tree=${lib.escapeShellArg repo.workTree}
      git_dir=${lib.escapeShellArg repo.gitDir}
      remote=${lib.escapeShellArg repo.remote}
      branch=${lib.escapeShellArg defaultBranch}
      conflict_branch=${lib.escapeShellArg conflictBranch}
      key=${lib.escapeShellArg config.sops.secrets.${deployKeySecret}.path}
      api_token_file=${lib.escapeShellArg config.sops.secrets.${giteaApiTokenSecret}.path}
      kuma_url_file=${lib.escapeShellArg config.sops.secrets.${uptimeKumaPushUrlSecret}.path}
      owner=${lib.escapeShellArg repo.owner}
      gitea_api=${lib.escapeShellArg "${giteaHttpBase}/api/v1/repos/${repo.owner}/${repo.repoName}"}
      state_file=${lib.escapeShellArg "${historyRoot}/${name}.state.json"}
      local_main_ref="refs/heads/$branch"
      remote_main_ref="refs/remotes/origin/$branch"
      conflict_ref="refs/heads/$conflict_branch"
      remote_conflict_ref="refs/remotes/origin/$conflict_branch"

      [ -d "$work_tree" ] || exit 0
      mkdir -p "$git_dir"

      exec 9>"${historyRoot}/${name}.lock"
      flock -n 9 || exit 0

      ssh_cmd="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
      export GIT_SSH_COMMAND="$ssh_cmd"

      git_repo() {
        git --git-dir="$git_dir" "$@"
      }

      git_wt() {
        git --git-dir="$git_dir" --work-tree="$work_tree" "$@"
      }

      has_ref() {
        git_repo show-ref --verify --quiet "$1"
      }

      send_kuma() {
        status="$1"
        message="$2"
        [ -r "$kuma_url_file" ] || return 0
        kuma_url_raw="$(tr -d '\n' < "$kuma_url_file")"
        [ -n "$kuma_url_raw" ] || return 0
        # Normalize to the push endpoint path so we don't send duplicate query keys
        # when the stored URL already includes defaults like ?status=up&msg=OK&ping=.
        kuma_url="''${kuma_url_raw%%\?*}"
        [ -n "$kuma_url" ] || return 0
        curl -fsS --max-time 15 --get \
          --data-urlencode "status=$status" \
          --data-urlencode "msg=$message" \
          --data-urlencode "ping=" \
          "$kuma_url" >/dev/null || true
      }

      conflict_heartbeat_message() {
        msg="notes-history ${name}: outstanding conflict on $conflict_branch"
        if [ -f "$state_file" ]; then
          pr_url="$(jq -r '.pr_url // empty' "$state_file" 2>/dev/null || true)"
          if [ -n "$pr_url" ]; then
            msg="$msg PR: $pr_url"
          fi
        fi
        printf '%s' "$msg"
      }

      finish_success() {
        up_msg="notes-history ${name}: heartbeat up on $branch"
        if [ $# -ge 1 ] && [ -n "$1" ]; then
          up_msg="$1"
        fi

        down_msg=""
        if [ $# -ge 2 ] && [ -n "$2" ]; then
          down_msg="$2"
        fi

        if has_ref "$remote_conflict_ref"; then
          if [ -z "$down_msg" ]; then
            down_msg="$(conflict_heartbeat_message)"
          fi
          send_kuma "down" "$down_msg"
        else
          send_kuma "up" "$up_msg"
        fi
        exit 0
      }

      ensure_exclude_line() {
        pattern="$1"
        exclude_file="$git_dir/info/exclude"
        mkdir -p "$git_dir/info"
        if [ -f "$exclude_file" ] && grep -Fqx "$pattern" "$exclude_file"; then
          return 0
        fi
        echo "$pattern" >> "$exclude_file"
      }

      ensure_managed_gitignore_block() {
        gitignore_file="$work_tree/.gitignore"
        begin_marker="# notes-history managed block"
        end_marker="# end notes-history managed block"
        managed_block="$(cat <<'EOF'
      # notes-history managed block
      .obsidian/workspace.json
      .stfolder
      .stignore
      .stversions
      *.sync-conflict-*
      # end notes-history managed block
      EOF
      )"

        if [ ! -f "$gitignore_file" ]; then
          printf '%s\n' "$managed_block" > "$gitignore_file"
          return 0
        fi

        tmp_file="$(mktemp "${historyRoot}/.${name}.gitignore.XXXXXX")"
        awk -v begin="$begin_marker" -v end="$end_marker" -v block="$managed_block" '
          BEGIN {
            in_block = 0;
            replaced = 0;
          }
          $0 == begin {
            if (replaced == 0) {
              print block;
              replaced = 1;
            }
            in_block = 1;
            next;
          }
          $0 == end {
            in_block = 0;
            next;
          }
          in_block == 0 {
            print;
          }
          END {
            if (replaced == 0) {
              if (NR > 0) {
                print "";
              }
              print block;
            }
          }
        ' "$gitignore_file" > "$tmp_file"
        mv "$tmp_file" "$gitignore_file"
      }

      worktree_matches_ref() {
        ref="$1"
        idx="$(mktemp "${historyRoot}/.${name}.index.XXXXXX")"
        if ! GIT_INDEX_FILE="$idx" git_wt read-tree "$ref" >/dev/null 2>&1; then
          rm -f "$idx"
          return 1
        fi
        GIT_INDEX_FILE="$idx" git_wt add -A
        if GIT_INDEX_FILE="$idx" git_wt diff --cached --ignore-cr-at-eol --quiet "$ref" --; then
          rm -f "$idx"
          return 0
        fi
        rm -f "$idx"
        return 1
      }

      ensure_conflict_pr() {
        [ -r "$api_token_file" ] || return 0
        api_token="$(tr -d '\n' < "$api_token_file")"
        [ -n "$api_token" ] || return 0

        pulls_url="$gitea_api/pulls"
        pulls_json=""
        if ! pulls_json="$(curl -fsS \
          -H "Authorization: token $api_token" \
          --get \
          --data-urlencode "state=open" \
          --data-urlencode "base=$branch" \
          --data-urlencode "head=$owner:$conflict_branch" \
          "$pulls_url" 2>/dev/null)"; then
          return 0
        fi

        existing_number="$(printf '%s' "$pulls_json" | jq -r '.[0].number // empty')"
        if [ -n "$existing_number" ]; then
          printf '%s' "$pulls_json" | jq -r '.[0].html_url // empty'
          return 0
        fi

        now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        payload="$(jq -nc \
          --arg title "notes(${name}): sync conflict on $now" \
          --arg head "$conflict_branch" \
          --arg base "$branch" \
          --arg body "Automated conflict branch created by notes-history service on kirby." \
          '{title: $title, head: $head, base: $base, body: $body}')"
        if pulls_json="$(curl -fsS \
          -X POST \
          -H "Authorization: token $api_token" \
          -H "Content-Type: application/json" \
          -d "$payload" \
          "$pulls_url" 2>/dev/null)"; then
          printf '%s' "$pulls_json" | jq -r '.html_url // empty'
        fi
      }

      if [ ! -d "$git_dir/objects" ]; then
        git init --bare "$git_dir"
      fi

      git_repo config user.name ${lib.escapeShellArg gitIdentityName}
      git_repo config user.email ${lib.escapeShellArg gitIdentityEmail}
      git_repo config core.autocrlf false
      git_repo config core.safecrlf false
      git_repo symbolic-ref HEAD "$local_main_ref" >/dev/null 2>&1 || true

      ensure_exclude_line ".obsidian/workspace.json"
      ensure_exclude_line ".stfolder"
      ensure_exclude_line ".stignore"
      ensure_exclude_line ".stversions"
      ensure_exclude_line "*.sync-conflict-*"

      stignore_file="$work_tree/.stignore"
      if [ ! -e "$stignore_file" ]; then
        printf '%s\n' '#include .stignore-sync' > "$stignore_file"
      fi
      ensure_managed_gitignore_block

      current_remote="$(git_repo remote get-url origin 2>/dev/null || true)"
      if [ -z "$current_remote" ]; then
        git_repo remote add origin "$remote"
      elif [ "$current_remote" != "$remote" ]; then
        git_repo remote set-url origin "$remote"
      fi

      git_repo fetch --prune origin

      if ! has_ref "$local_main_ref" && has_ref "$remote_main_ref"; then
        git_repo update-ref "$local_main_ref" "$remote_main_ref"
      fi

      git_repo symbolic-ref HEAD "$local_main_ref" >/dev/null 2>&1 || true
      git_wt reset --mixed -q "$local_main_ref" >/dev/null 2>&1 || true

      local_dirty=0
      if has_ref "$local_main_ref"; then
        if ! worktree_matches_ref "$local_main_ref"; then
          local_dirty=1
        fi
      elif [ -n "$(git_wt status --porcelain --untracked-files=all)" ]; then
        local_dirty=1
      fi

      local_ahead=0
      remote_ahead=0
      if has_ref "$local_main_ref" && has_ref "$remote_main_ref"; then
        ahead_count="$(git_repo rev-list --count "$remote_main_ref..$local_main_ref")"
        behind_count="$(git_repo rev-list --count "$local_main_ref..$remote_main_ref")"
        if [ "$ahead_count" -gt 0 ]; then
          local_ahead=1
        fi
        if [ "$behind_count" -gt 0 ]; then
          remote_ahead=1
        fi
      elif has_ref "$local_main_ref" && ! has_ref "$remote_main_ref"; then
        local_ahead=1
      elif ! has_ref "$local_main_ref" && has_ref "$remote_main_ref"; then
        remote_ahead=1
      fi

      prior_mode=""
      if [ -f "$state_file" ]; then
        prior_mode="$(jq -r '.mode // empty' "$state_file" 2>/dev/null || true)"
      fi

      clear_conflict_state() {
        if has_ref "$remote_conflict_ref"; then
          return 0
        fi
        rm -f "$state_file"
      }

      post_merge_local_changes=0
      # If we were in conflict mode and the remote conflict branch is gone,
      # treat it as resolved upstream (usually merged/closed). Only auto-converge
      # if local content is clean so we never drop new Syncthing edits.
      if [ "$prior_mode" = "conflict" ] && ! has_ref "$remote_conflict_ref"; then
        if [ "$local_dirty" -eq 0 ] && [ "$local_ahead" -eq 0 ]; then
          if [ "$remote_ahead" -eq 1 ] && has_ref "$remote_main_ref"; then
            git_repo update-ref "$local_main_ref" "$remote_main_ref"
            git_wt reset --hard -q "$local_main_ref"
          fi
          clear_conflict_state
          finish_success "notes-history ${name}: conflict resolved on $branch"
        fi
        post_merge_local_changes=1
      fi

      # If local main is behind but work tree already matches remote main, fast-forward.
      if [ "$remote_ahead" -eq 1 ] && [ "$local_dirty" -eq 1 ] && [ "$local_ahead" -eq 0 ] && has_ref "$remote_main_ref"; then
        if worktree_matches_ref "$remote_main_ref"; then
          git_repo update-ref "$local_main_ref" "$remote_main_ref"
          git_wt reset --hard -q "$local_main_ref"
          clear_conflict_state
          finish_success
        fi
      fi

      if [ "$remote_ahead" -eq 0 ] && [ "$local_dirty" -eq 1 ]; then
        git_wt add -A
        if ! git_wt diff --cached --quiet; then
          timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
          git_wt -c commit.gpgSign=false commit -m "notes(${name}): $timestamp"
        fi
        git_repo push -u origin "$branch"
        clear_conflict_state
        finish_success
      fi

      if [ "$remote_ahead" -eq 1 ] && [ "$local_dirty" -eq 0 ] && [ "$local_ahead" -eq 0 ]; then
        git_repo update-ref "$local_main_ref" "$remote_main_ref"
        git_wt reset --hard -q "$local_main_ref"
        clear_conflict_state
        finish_success
      fi

      if [ "$remote_ahead" -eq 0 ] && [ "$local_dirty" -eq 0 ] && [ "$local_ahead" -eq 1 ]; then
        git_repo push -u origin "$branch"
        clear_conflict_state
        finish_success
      fi

      if [ "$remote_ahead" -eq 1 ] && { [ "$local_dirty" -eq 1 ] || [ "$local_ahead" -eq 1 ]; }; then
        # Create/update a long-lived conflict branch and PR.
        if has_ref "$remote_conflict_ref"; then
          git_repo update-ref "$conflict_ref" "$remote_conflict_ref"
        elif ! has_ref "$conflict_ref" && has_ref "$remote_main_ref"; then
          git_repo update-ref "$conflict_ref" "$remote_main_ref"
        elif ! has_ref "$conflict_ref" && has_ref "$local_main_ref"; then
          git_repo update-ref "$conflict_ref" "$local_main_ref"
        fi

        if [ "$local_dirty" -eq 1 ]; then
          git_repo symbolic-ref HEAD "$conflict_ref"
          git_wt reset --mixed -q "$conflict_ref" >/dev/null 2>&1 || true
          git_wt add -A
          if ! git_wt diff --cached --quiet; then
            timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            git_wt -c commit.gpgSign=false commit -m "notes(${name}): conflict snapshot $timestamp"
          fi
        elif [ "$local_ahead" -eq 1 ] && has_ref "$local_main_ref"; then
          git_repo update-ref "$conflict_ref" "$local_main_ref"
        fi

        git_repo push -u origin "$conflict_branch"
        pr_url="$(ensure_conflict_pr || true)"
        conflict_head="$(git_repo rev-parse "$conflict_ref" 2>/dev/null || true)"
        now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        jq -nc \
          --arg mode "conflict" \
          --arg branch "$conflict_branch" \
          --arg pr_url "$pr_url" \
          --arg conflict_head "$conflict_head" \
          --arg updated_at "$now" \
          '{mode: $mode, branch: $branch, pr_url: $pr_url, conflict_head: $conflict_head, updated_at: $updated_at}' \
          > "$state_file"

        alert_msg="notes-history ${name}: outstanding conflict on $conflict_branch"
        if [ "$post_merge_local_changes" -eq 1 ]; then
          alert_msg="notes-history ${name}: local changes arrived after conflict merge; outstanding conflict on $conflict_branch"
        fi
        if [ -n "$pr_url" ]; then
          alert_msg="$alert_msg PR: $pr_url"
        fi

        git_repo update-ref "$remote_conflict_ref" "$conflict_head" >/dev/null 2>&1 || true
        finish_success "" "$alert_msg"
      fi

      # Nothing to do (already in sync).
      if [ "$remote_ahead" -eq 0 ] && [ "$local_dirty" -eq 0 ] && [ "$local_ahead" -eq 0 ]; then
        clear_conflict_state
        finish_success
      fi

      # Fallback: create regular snapshot commit and push main.
      git_wt add -A
      if ! git_wt diff --cached --quiet; then
        timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        git_wt -c commit.gpgSign=false commit -m "notes(${name}): $timestamp"
      fi
      git_repo push -u origin "$branch"
      clear_conflict_state
      finish_success
    '';
  };

  mkAlertService = {
    description = "Send notes-history failure alerts";
    path = with pkgs; [coreutils curl jq systemd];
    serviceConfig = {
      Type = "oneshot";
      User = config.my.user;
      Group = "users";
      Environment = "FAILED_UNIT=%i";
    };
    script = ''
      set -euo pipefail

      kuma_url_file=${lib.escapeShellArg config.sops.secrets.${uptimeKumaPushUrlSecret}.path}
      failed_unit="''${FAILED_UNIT:-unknown}"
      repo="''${failed_unit#notes-history-}"
      repo="''${repo%.service}"
      state_file=${lib.escapeShellArg historyRoot}/"''${repo}.state.json"

      [ -r "$kuma_url_file" ] || exit 0
      kuma_url_raw="$(tr -d '\n' < "$kuma_url_file")"
      [ -n "$kuma_url_raw" ] || exit 0
      kuma_url="''${kuma_url_raw%%\?*}"
      [ -n "$kuma_url" ] || exit 0

      reason="$(systemctl show -p Result --value "$failed_unit" 2>/dev/null || true)"
      status="$(systemctl show -p ExecMainStatus --value "$failed_unit" 2>/dev/null || true)"
      msg="notes-history failure: ''${failed_unit} (result=''${reason:-unknown}, status=''${status:-unknown})"

      if [ -f "$state_file" ]; then
        pr_url="$(jq -r '.pr_url // empty' "$state_file" 2>/dev/null || true)"
        if [ -n "$pr_url" ]; then
          msg="''${msg} PR: ''${pr_url}"
        fi
      fi

      curl -fsS --max-time 15 --get \
        --data-urlencode "status=down" \
        --data-urlencode "msg=$msg" \
        --data-urlencode "ping=" \
        "$kuma_url" >/dev/null || true
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
  sops.secrets.${giteaApiTokenSecret} = {
    owner = config.my.user;
    group = "users";
    mode = "0400";
  };
  sops.secrets.${uptimeKumaPushUrlSecret} = {
    owner = config.my.user;
    group = "users";
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d ${historyRoot} 0750 ${config.my.user} users - -"
  ];

  systemd.services =
    (lib.mapAttrs' (n: r: lib.nameValuePair "notes-history-${n}" (mkService n r)) repos)
    // {
      "notes-history-alert@" = mkAlertService;
    };
  systemd.timers = lib.mapAttrs' (n: _: lib.nameValuePair "notes-history-${n}" (mkTimer n)) repos;
}
