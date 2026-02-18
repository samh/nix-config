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
Canonical technical docs:
- [`hosts/kirby/notes-history.md`](./notes-history.md)

Quick bootstrap:
1. Create repos `samh/notes-shared` and `samh/notes-personal` in Gitea.
2. Generate deploy key:
   - `cd /etc/nixos`
   - `./scripts/generate-sops-deploy-key.sh`
3. Create bot token and Uptime Kuma push URL; store secrets:
   - `notes-history-gitea-deploy-key`
   - `notes-history-gitea-api-token`
   - `notes-history-uptime-kuma-push-url`
4. Rebuild and smoke test:
   - `sudo nixos-rebuild switch`
   - `sudo systemctl start notes-history-notes-shared.service notes-history-notes-personal.service`

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
