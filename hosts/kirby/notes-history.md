# Kirby Notes History (Syncthing + Git + Gitea)

This is the canonical technical documentation for notes history on `kirby`.

## Overview
- Syncthing remains real-time file sync for notes.
- `~/Notes/Notes-Shared` and `~/Notes/Notes-Personal` are the live working trees.
- Git metadata is stored outside Syncthing folders as bare repos under `/var/lib/notes-history`.
- `notes-history-*` systemd timers perform bidirectional sync with Gitea.
- Conflict handling is PR-based using `conflict/kirby`.

## Source Of Truth
- Implementation: `hosts/kirby/notes-history.nix`
- Host setup index: `hosts/kirby/README.md`
- Obsidian quick note: `/home/samh/Notes/Notes-Shared/Software/Notes-Knowledge/Obsidian/Obsidian Notes History.md`

## Paths And Repos
Work trees (Syncthing-managed):
```text
/home/samh/Notes/Notes-Shared
/home/samh/Notes/Notes-Personal
```

Git dirs (bare repos):
```text
/var/lib/notes-history/notes-shared.git
/var/lib/notes-history/notes-personal.git
```

State files:
```text
/var/lib/notes-history/notes-shared.state.json
/var/lib/notes-history/notes-personal.state.json
```

Remotes:
```text
gitea@gitea.kirby.hartsfield.xyz:samh/notes-shared.git
gitea@gitea.kirby.hartsfield.xyz:samh/notes-personal.git
```

## Branch Model
- Primary branch: `main`
- Conflict branch: `conflict/kirby` (long-lived branch reused by automation)

## Services
- `notes-history-notes-shared.service`
- `notes-history-notes-personal.service`
- `notes-history-notes-shared.timer`
- `notes-history-notes-personal.timer`
- `notes-history-alert@.service`

Timer cadence:
- Every 10 minutes (`OnUnitActiveSec=10m`)
- Randomized delay up to 120s

## Secrets
Required SOPS keys:
- `notes-history-gitea-deploy-key` (SSH key for Git push/pull)
- `notes-history-gitea-api-token` (Gitea API token for PR creation/update)
- `notes-history-uptime-kuma-push-url` (Uptime Kuma Push monitor URL)

Runtime secret files:
- `/run/secrets/notes-history-gitea-deploy-key`
- `/run/secrets/notes-history-gitea-api-token`
- `/run/secrets/notes-history-uptime-kuma-push-url`

## Setup And Bootstrap
1. Create Gitea repos if needed:
   - `samh/notes-shared`
   - `samh/notes-personal`
2. Generate deploy key and store private key in SOPS:
   - `cd /etc/nixos`
   - `./scripts/generate-sops-deploy-key.sh`
3. Add printed deploy public key to both repos:
   - Repo -> Settings -> Deploy Keys -> Add Deploy Key
   - Enable write access.
4. Create bot user for PR automation (for example `notes-history-bot`).
5. Add bot as collaborator on both repos with minimum repo access required for PR operations.
6. Sign in as bot and create token:
   - Settings -> Applications -> Access Tokens
   - Store token as `notes-history-gitea-api-token`
7. Create Uptime Kuma Push monitor and store URL as `notes-history-uptime-kuma-push-url`.
8. Confirm all three keys exist in `secrets/secrets.yaml`.
9. Rebuild:
   - `cd /etc/nixos`
   - `sudo nixos-rebuild switch`
10. Smoke test:
   - `sudo systemctl start notes-history-notes-shared.service notes-history-notes-personal.service`

## Sync Behavior
Each run:
1. Fetches `origin/main`.
2. Evaluates local work tree state vs local/remote main.
3. Pushes local snapshots to `main` when only local changed.
4. Fast-forwards local work tree when only remote changed.
5. Uses conflict branch/PR when both changed.

Local file hygiene enforced by service:
- Creates `.stignore` if missing with:
  - `#include .stignore-sync`
- Maintains a managed `.gitignore` block.
- Excludes workspace/syncthing noise from tracked history.

## Conflict Lifecycle
When both local and remote changed:
1. Create/update `conflict/kirby`.
2. Push branch to origin.
3. Create/update PR `conflict/kirby -> main` via Gitea API.
4. Notify Uptime Kuma (`down`) with context and PR URL if available.

When PR is merged/branch deleted:
1. If local is clean, converge back to `main`, clear conflict state, send `up`.
2. If new local changes arrived in the meantime, preserve them and start a new conflict cycle (no data loss).

## Alerts / Monitoring
The service sends Uptime Kuma push events for:
- Conflict created/updated (`down`)
- Conflict resolved (`up`)
- Unit failure (`down` via `OnFailure`)

It does not currently send periodic heartbeat `up` on every successful timer run.

## Operations Quick Commands
```bash
# Rebuild
cd /etc/nixos
sudo nixos-rebuild switch

# Trigger now
sudo systemctl start notes-history-notes-shared.service notes-history-notes-personal.service

# Timer status
systemctl list-timers 'notes-history-*'
```

```bash
# Logs
journalctl -u notes-history-notes-shared.service -n 80 --no-pager
journalctl -u notes-history-notes-personal.service -n 80 --no-pager
journalctl -u notes-history-alert@* -n 80 --no-pager
```

```bash
# Inspect bare repos
git --git-dir=/var/lib/notes-history/notes-shared.git log --oneline -n 10
git --git-dir=/var/lib/notes-history/notes-personal.git log --oneline -n 10
git --git-dir=/var/lib/notes-history/notes-shared.git remote -v
git --git-dir=/var/lib/notes-history/notes-personal.git remote -v
```

## Using Git In The Notes Work Trees
`status`, `diff`, and similar commands require both `--git-dir` and `--work-tree`.

Working examples:
```bash
git --git-dir=/var/lib/notes-history/notes-personal.git --work-tree=/home/samh/Notes/Notes-Personal status
git --git-dir=/var/lib/notes-history/notes-personal.git --work-tree=/home/samh/Notes/Notes-Personal diff
git --git-dir=/var/lib/notes-history/notes-shared.git --work-tree=/home/samh/Notes/Notes-Shared status
```

`--git-dir` alone is only for commands that do not need a work tree (for example `log`):
```bash
git --git-dir=/var/lib/notes-history/notes-personal.git log --oneline -n 20
```

Optional shell helpers:
```bash
gnotes-personal() {
  git --git-dir=/var/lib/notes-history/notes-personal.git --work-tree=/home/samh/Notes/Notes-Personal "$@"
}

gnotes-shared() {
  git --git-dir=/var/lib/notes-history/notes-shared.git --work-tree=/home/samh/Notes/Notes-Shared "$@"
}
```

Then:
```bash
gnotes-personal status
gnotes-personal diff
gnotes-shared log --oneline -n 20
```

## Troubleshooting
- Push/auth failures:
  - Verify deploy key installed on both Gitea repos.
  - Verify SSH auth:
    - `sudo -u samh bash -lc 'k=/run/secrets/notes-history-gitea-deploy-key; GIT_SSH_COMMAND="ssh -i $k -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" git ls-remote gitea@gitea.kirby.hartsfield.xyz:samh/notes-shared.git'`
- PR not auto-created:
  - Verify API token exists, belongs to bot account, and has repo scope.
  - Check logs for `ensure_conflict_pr`.
- Alerts missing:
  - Verify Uptime Kuma secret file exists and contains valid push URL.
