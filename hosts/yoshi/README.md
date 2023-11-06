# yoshi

> New(er) Storage Server
>
> Z77 Core i5-3770K (2012)

## State / Manual Setup Steps
1. *See [top-level README.md](../../README.md) for common steps.*
2. Borg backup for photos: `HEALTHCHECKS_URL_PHOTOS` in `/root/borgmatic.env`,
   password in `/root/borg-pass-photos`

## Notable Systemd Units

```
blocky.service
borgmatic.service
borgmatic.timer
jellyfin.service
nginx.service
tailscaled.service
```

Nextcloud:
```
nextcloud-cron.service
nextcloud-cron.timer
nextcloud-setup.service
nextcloud-update-plugins.service
nextcloud-update-plugins.timer
phpfpm-nextcloud.service
redis-nextcloud.service
```
