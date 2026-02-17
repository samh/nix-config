# kirby

> Dell OptiPlex 7050 Micro (purchased 2023)

## State / Manual Setup Steps
1. *See [top-level README.md](../../README.md) for common steps.*
2. Run `smbpasswd -a scanner` to set the samba password for the scanner
   shared folder.
3. Run `smbpasswd -a homeassistant` to set the samba password for the
   Home Assistant shared folder.
4. `tailscale up --advertise-tags=tag:server --advertise-routes=192.168.5.0/24,192.168.107.0/24,192.168.108.0/24`

#### Notes History (Syncthing + Gitea)
1. Create the repos in Gitea if they do not exist yet:
   - `samh/notes-shared`
   - `samh/notes-personal`
2. Generate/rotate the SSH deploy key and store the private key in SOPS:
   - `cd /etc/nixos`
   - `./scripts/generate-sops-deploy-key.sh`
   - This writes `notes-history-gitea-deploy-key` in `secrets/secrets.yaml`
     and prints the corresponding public key.
3. Add the printed deploy public key to both Gitea repos:
   - Repo -> Settings -> Deploy Keys -> Add Deploy Key
   - Enable write access so `notes-history` can push.
4. Create a dedicated Gitea bot account and API token for PR automation:
   - Create user (example): `notes-history-bot`.
   - Add `notes-history-bot` as collaborator on:
     - `samh/notes-shared`
     - `samh/notes-personal`
   - Grant only the minimum repo access needed for pull requests.
   - Sign in as `notes-history-bot`.
   - Bot user menu -> Settings -> Applications -> Access Tokens.
   - Generate a token (name suggestion: `notes-history-pr-bot`).
   - Grant repo permissions sufficient to list/create pull requests
     (and read repo metadata).
   - Copy token once and store in SOPS as `notes-history-gitea-api-token`.
   - Do not create this token under your personal user account.
5. Create a Uptime Kuma push URL for notes-history alerts:
   - Open Uptime Kuma UI.
   - Add New Monitor -> `Push`.
   - Name examples:
     - `notes-history-notes-shared`
     - `notes-history-notes-personal`
   - Copy the generated push URL and store in SOPS as
     `notes-history-uptime-kuma-push-url`.
   - Current service uses one URL for both repos; include repo name in monitor
     notifications/messages for context.
6. Add `kirby` Syncthing device ID after first startup:
   - After first Syncthing startup on kirby, get its device ID and add
   `hosts.kirby.syncthing_id` in `include/metadata.toml`, then add `kirby`
   to Notes folder `devices` lists on peers that share those folders.
7. Ensure `secrets/secrets.yaml` contains all required keys:
   - `notes-history-gitea-deploy-key`
   - `notes-history-gitea-api-token`
   - `notes-history-uptime-kuma-push-url`
8. Apply config:
   - `cd /etc/nixos`
   - `sudo nixos-rebuild switch`
9. Smoke test:
   - `sudo systemctl start notes-history-notes-shared.service notes-history-notes-personal.service`
   - `journalctl -u notes-history-notes-shared.service -n 80 --no-pager`
   - `journalctl -u notes-history-notes-personal.service -n 80 --no-pager`

#### Paperless Database
1. If the paperless services are running, stop them:
   ```
   sudo systemctl stop paperless\*
   ```
2. Create the database user and database:
   ```
   sudo -u postgres createuser paperless
   sudo -u postgres createdb -O paperless paperless
   ```
3. Load a database backup if available:
   ```
   sudo -u postgres psql paperless < paperless.sql
   ```
4. Start the paperless services:
   ```
   sudo systemctl start --all paperless\*
   ```

#### Karakeep Settings
Karakeep generates secrets and stores them in
```
/var/lib/karakeep/settings.env
```
This file may also be used for storing other settings, especially for
testing before adding to the Nix config. For example:

```dotenv
# Ollama via OpenWebUI on desktop
OPENAI_BASE_URL=https://openwebui.my.domain/api
OPENAI_API_KEY=sk-...
INFERENCE_TEXT_MODEL=gemma3:4b
INFERENCE_IMAGE_MODEL=gemma3:4b
INFERENCE_CONTEXT_LENGTH=32768
INFERENCE_FETCH_TIMEOUT_SEC=120
```
When finalized, we may want to move these to the Nix config and add
the secret to SOPS.

#### zigbee2mqtt Secrets
_Zigbee2MQTT is currently disabled (moved to ZHA in Home Assistant)._

1. Create a `secret.yaml` file in `/var/lib/zigbee2mqtt` with the following
   contents:
   ```
   auth_token: <token>
   mqtt_password: <password>
   ```

## Notable Systemd Units

```
blocky.service
borgmatic.service
borgmatic.timer
nginx.service
postgresql.service
tailscaled.service
uptime-kuma.service
```

Paperless:
```
systemctl status paperless\*
# Start needs "--all"
systemctl start --all paperless\*
```

Samba:
```
systemctl status samba\*
```
