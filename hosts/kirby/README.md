# kirby

> Dell OptiPlex 7050 Micro (purchased 2023)

## State / Manual Setup Steps
1. *See [top-level README.md](../../README.md) for common steps.*
2. Run `smbpasswd -a scanner` to set the samba password for the scanner
   shared folder.

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

## Notable Systemd Units

```
borgmatic.service
borgmatic.timer
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
