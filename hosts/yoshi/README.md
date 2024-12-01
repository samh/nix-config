# yoshi

> New(er) Storage Server
>
> Z77 Core i5-3770K (2012)

## State / Manual Setup Steps
1. *See [top-level README.md](../../README.md) for common steps.*
2. Run `smbpasswd -a samh` to set the samba password for myself.
3. Borg backup for photos: `HEALTHCHECKS_URL_PHOTOS` in `/root/borgmatic.env`,
   password in `/root/borg-pass-photos`
4. For Calibre Server, user database needs to exist:
   `/var/lib/calibre-server/server-users.sqlite`
   (created by Calibre GUI or command line); the GUI creates it at
   `~/.config/calibre/server-users.sqlite`.

### Nextcloud
1. "Office" in administration settings: need to set URL and
   "Allow list for WOPI requests" (seems like it should be the IP that is
   resolved from the Nextcloud hostname).

## Notable Systemd Units

```
blocky.service
borgmatic.service
borgmatic.timer
calibre-server.service
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

Collabora Online (Nextcloud Office):

```
coolwsd.service
coolwsd-systemplate-setup.service
```

Samba:
```
systemctl status samba\*
```
