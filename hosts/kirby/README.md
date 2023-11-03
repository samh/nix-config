# kirby

> Dell OptiPlex 7050 Micro (purchased 2023)

## State / Manual Setup Steps
1. *See [top-level README.md](../../README.md) for common steps.*
2. Run `smbpasswd -a scanner` to set the samba password for the scanner
   shared folder.
3. Run `smbpasswd -a homeassistant` to set the samba password for the
   Home Assistant shared folder.
4. `tailscale up --advertise-tags=tag:server --advertise-routes=192.168.5.0/24,192.168.107.0/24,192.168.108.0/24`

### PostgreSQL Setup
1. To allow `borgmatic` (running as root) to dump PostgreSQL databases,
   I create a `root` user with permission to read everything:
   ```
   sudo -u postgres createuser --role=pg_read_all_data root
   ```

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

#### zigbee2mqtt Secrets
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
zigbee2mqtt.service
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
