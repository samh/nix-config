# Shared Authentication with Kanidm

This repo uses a two-node Kanidm deployment on `kirby` and `yoshi` to provide:

- OIDC at `https://sso.hartsfield.xyz`
- LDAPS at `ldap.hartsfield.xyz`
- local-LAN operation even when the public internet is unavailable
- phase 1 manual failover with a clean path to a phase 2 LAN VIP

## Architecture

- `kirby` and `yoshi` both run Kanidm.
- `nginx` fronts the shared OIDC hostname on both hosts.
- Kanidm listens directly on LDAPS for `ldap.hartsfield.xyz`.
- Local DNS comes from Blocky on both hosts.
- Public DNS comes from Cloudflare.
- `sso.hartsfield.xyz` is public.
- `ldap.hartsfield.xyz` is local-only in phase 1.
- Phase 1 keeps `kirby` as the active node and uses manual failover.

The shared auth hostnames are:

- `sso.hartsfield.xyz`
- `ldap.hartsfield.xyz`

Applications should always use those shared names, never `kirby`-specific or `yoshi`-specific issuer URLs.

## Repo Layout

- [`include/kanidm-auth.nix`](../include/kanidm-auth.nix): shared Kanidm, DNS, and OIDC client provisioning
- [`hosts/kirby/configuration.nix`](../hosts/kirby/configuration.nix): `kirby` host integration
- [`hosts/yoshi/configuration.nix`](../hosts/yoshi/configuration.nix): `yoshi` host integration
- [`hosts/kirby/homarr.nix`](../hosts/kirby/homarr.nix): Homarr OIDC wiring
- [`docs/auth-phase-2-vip.md`](auth-phase-2-vip.md): planned LAN VIP follow-up

## SOPS Secrets To Create

Add these secrets to `secrets/secrets.yaml` before deployment:

- `kanidm/admin_password`
- `kanidm/idm_admin_password`
- `kanidm/oauth2/homarr_client_secret`
- `kanidm/oauth2/audiobookshelf_client_secret`
- `acme-env`

Notes:

- `acme-env` must contain the Cloudflare API token in the format expected by lego.
- OIDC client secrets can be random high-entropy strings.
- The Kanidm admin passwords are used by the provisioning step on the active node.

## Cloudflare Setup

Create this DNS record in Cloudflare:

- `sso.hartsfield.xyz`

Recommended phase 1 settings:

- record type: `A` and `AAAA` as appropriate for your network
- proxy mode: `DNS only`
- TTL: low, such as `Auto` or `60s`

Why `DNS only`:

- OIDC should connect directly to the active host
- `ldap.hartsfield.xyz` stays local-only in phase 1

Why the certificate still includes `ldap.hartsfield.xyz`:

- the repo uses DNS-01 ACME issuance
- `ldap.hartsfield.xyz` does not need a public `A` or `AAAA` record for certificate issuance
- local LDAPS clients can still validate the certificate cleanly

Phase 1 public DNS target:

- point `sso.hartsfield.xyz` at the currently active host
- default active host is `kirby`

Public failover procedure:

1. Change the Cloudflare record for `sso.hartsfield.xyz` to the standby host.
2. Wait for TTL expiry.
3. Verify the standby host serves OIDC discovery.

## Local DNS Setup

Local clients should resolve the shared auth names through Blocky, not through public DNS.

This is already handled declaratively in [`include/kanidm-auth.nix`](../include/kanidm-auth.nix):

- both Blocky servers answer `sso.hartsfield.xyz`
- both Blocky servers answer `ldap.hartsfield.xyz`
- both names point to the host selected by `my.auth.kanidm.manualPrimaryHost`

This means:

- LAN clients use local DNS for both OIDC and LDAPS
- only `sso.hartsfield.xyz` depends on Cloudflare for public resolution
- `ldap.hartsfield.xyz` keeps working on the LAN even if the internet is unavailable

Phase 1 local failover procedure:

1. Change `my.auth.kanidm.manualPrimaryHost` from `kirby` to `yoshi` in both host configs.
2. Rebuild both `kirby` and `yoshi` so both Blocky instances answer consistently.
3. Wait for the local DNS TTL to expire.
4. Verify `sso.hartsfield.xyz` and `ldap.hartsfield.xyz` now resolve to `yoshi`.

## Kanidm Bootstrap and Replication

Kanidm replication needs one manual certificate exchange after the first deploy.

Initial deployment:

1. Deploy both hosts with `peerReplicationCertificate = null`.
2. Wait for both `kanidm.service` units to start.
3. On each host, print its replication certificate:

```shell
sudo -u kanidm kanidmd show-replication-certificate -c /etc/kanidm/server.toml
```

4. Copy `kirby`'s certificate into `yoshi`'s `my.auth.kanidm.peerReplicationCertificate`.
5. Copy `yoshi`'s certificate into `kirby`'s `my.auth.kanidm.peerReplicationCertificate`.
6. Rebuild both hosts.

Phase 1 replication sync:

- `kirby` is the primary node
- `yoshi` is configured as the automatic refresh consumer

If the cluster reports a domain UUID mismatch on first join, run on `yoshi`:

```shell
sudo -u kanidm kanidmd refresh-replication-consumer -c /etc/kanidm/server.toml
```

## Homarr

Homarr is configured declaratively for mixed local credentials plus OIDC:

- issuer: `https://sso.hartsfield.xyz/oauth2/openid/homarr`
- client id: `homarr`
- scopes: `openid email profile groups_name`

Break-glass access:

- credentials auth remains enabled so a local Homarr admin can still log in even if OIDC is being repaired

Recommended Kanidm groups:

- `homarr-users`
- `homarr-admins`

## Audiobookshelf

Audiobookshelf does not have the same declarative OIDC surface in the NixOS module, so the server-side prerequisites are prepared in this repo and the app-side toggle is still manual in the app UI.

Prepared in this repo:

- Kanidm OIDC client `audiobookshelf`
- client secret secret name
- custom claim map `abs_roles`

Use these values in the Audiobookshelf admin UI:

- issuer / discovery base: `https://sso.hartsfield.xyz/oauth2/openid/audiobookshelf`
- client id: `audiobookshelf`
- client secret: value from `kanidm/oauth2/audiobookshelf_client_secret`
- group claim: `abs_roles`

Configured redirect URIs in Kanidm:

- `https://audiobookshelf.yoshi.hartsfield.xyz/auth/openid/callback`
- `audiobookshelf://oauth`

The custom `abs_roles` claim maps:

- `audiobookshelf-users` -> `user`
- `audiobookshelf-admins` -> `admin`

## Validation Checklist

- `nix flake check --no-build`
- `systemctl status kanidm`
- `systemctl status nginx`
- `dig @192.168.5.50 sso.hartsfield.xyz`
- `dig @192.168.5.40 sso.hartsfield.xyz`
- open `https://sso.hartsfield.xyz/oauth2/openid/homarr/.well-known/openid-configuration`
- confirm Homarr login succeeds
- confirm local DNS resolution still works with WAN disconnected

## Troubleshooting

- If OIDC discovery fails, confirm the shared `sso` hostname resolves to the expected node on both public and local DNS.
- If LDAPS certificate validation fails, confirm both `sso` and `ldap` are covered by the shared ACME certificate.
- If replication does not start, confirm the peer replication certificate was copied correctly and the replication port is reachable between the hosts.
- If Audiobookshelf login fails, verify the UI-side OIDC settings and confirm the `abs_roles` claim is being requested and returned.
