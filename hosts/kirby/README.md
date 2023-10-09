# kirby

> Dell OptiPlex 7050 Micro (purchased 2023)

## State / Manual Setup Steps
1. *See [top-level README.md](../../README.md) for common steps.*
2. Run `smbpasswd -a scanner` to set the samba password for the scanner
   shared folder.

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
```

Samba:
```
systemctl status samba\*
```
