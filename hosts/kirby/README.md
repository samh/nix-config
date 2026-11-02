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
3. Create bot token and per-repo Uptime Kuma push URLs; store secrets:
   - `notes-history-gitea-deploy-key`
   - `notes-history-gitea-api-token`
   - `notes-history-uptime-kuma-push-url-notes-shared`
   - `notes-history-uptime-kuma-push-url-notes-personal`
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

## Network monitoring

Uptime Kuma: <https://uptime-kuma.kirby.hartsfield.xyz/dashboard>.
The `Network (kirby)` group contains twelve checks created through Kuma's app API:

| Checks | Targets |
| --- | --- |
| Ping | OPNsense `192.168.5.1`, lakitu `192.168.10.10`, AT&T RG `192.168.1.254`, Cloudflare `1.1.1.1`, Quad9 `9.9.9.9` |
| DNS A lookup for `example.com` | kirby `192.168.5.50`, lakitu `192.168.10.10`, Cloudflare `1.1.1.1`, Quad9 `9.9.9.9` |
| TCP port 443 | Cloudflare `1.1.1.1`, Quad9 `9.9.9.9` |
| HTTPS with certificate verification | `https://1.1.1.1/cdn-cgi/trace`; uses a literal IP and does not depend on local DNS |

Checks run every twenty seconds with no retries, preserving single failed
checks in history. No notification destinations are attached to the new group
or checks. Existing monitors and their notification settings are unchanged.
Kuma's existing DNS checks for `yoshi.hartsfield.xyz` remain useful for local
records; the new public-name checks also exercise the public-resolution path,
although cached answers can mask upstream DNS failures.

SmokePing configuration is in [`smokeping.nix`](./smokeping.nix). Its intended
URL after activation is <https://smokeping.kirby.hartsfield.xyz/>. The dashboard
allows home IPv4 networks and Tailscale addresses and uses kirby's existing
wildcard TLS certificate. It measures eight IPv4 targets: OPNsense, lakitu,
the AT&T gateway, both Cloudflare addresses, both Quad9 addresses, and Google
`8.8.8.8`. Each thirty-second measurement contains twenty pings per target.
RRD retention is seven days at thirty-second resolution, sixty days at
six-minute resolution, and a year at hourly resolution. Changing the base
interval or ping count requires migrating the RRD files.

SmokePing data lives in `/var/lib/smokeping/data`, included in the general
Borgmatic backup. Check `smokeping.service`, `fcgiwrap-smokeping.service`, and
`nginx.service` after activation. Initial graphs need a few measurement cycles.
The configuration and parser have been validated; live deployment is pending
sudo activation on kirby.

Both services observe from behind OPNsense. Keep the temporary desktop monitor
for five-second samples during this investigation, and compare a wired laptop
on the AT&T gateway when possible. A failed public probe alone cannot identify
which router, link, or remote target failed.

For a later Prometheus/Grafana setup, start with Blackbox Exporter for separate
ICMP, TCP, DNS and HTTPS probes, Node Exporter on kirby/lakitu for host and
interface metrics, and appropriate OPNsense interface/gateway metrics. Kuma's
`/metrics` endpoint can also be scraped using a Kuma API key. Correlate these
metrics in dashboards before adding automated attribution. SmokePing keeps its
own RRD history; a Prometheus ping exporter would take separate measurements.

## Notable Systemd Units

```
blocky.service
borgmatic.service
borgmatic.timer
nginx.service
postgresql.service
smokeping.service
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
