# Phase 2 Plan: LAN VIP for Shared Authentication

Phase 1 validates the shared hostnames, Kanidm replication, local DNS behavior, and manual failover. Phase 2 removes the need to edit local DNS during a LAN-side failover by introducing a shared virtual IP.

## Goal

Move local access for:

- `sso.hartsfield.xyz`
- `ldap.hartsfield.xyz`

from a manually selected host IP to a LAN VIP that can float between `kirby` and `yoshi`.

Public DNS can remain manual in this phase. The VIP is for local availability.

## Proposed Design

- Reserve one unused LAN address for the auth VIP.
- Run `keepalived` on both `kirby` and `yoshi`.
- `kirby` starts as higher priority owner of the VIP.
- `yoshi` takes over when `kirby` fails or is intentionally demoted.
- Blocky on both hosts answers `sso` and `ldap` with the VIP rather than a host IP.

## Requirements

- a free address on `192.168.5.0/24`
- `keepalived` on both hosts
- health-check logic that confirms Kanidm and nginx are healthy enough for the node to own the VIP
- firewall rules allowing the VIP owner to serve HTTPS and LDAPS

## Expected Config Changes

- add a shared VIP option to the auth module
- switch Blocky mappings from `manualPrimaryHost` lookup to the VIP
- add `keepalived` configuration on both hosts
- add health checks for:
  - local Kanidm HTTPS listener
  - local nginx shared SSO vhost
  - optional LDAPS listener

## Validation

1. Confirm both hosts can start with `keepalived`.
2. Confirm the VIP lands on `kirby`.
3. Confirm `sso` and `ldap` resolve to the VIP from both Blocky servers.
4. Stop Kanidm or `keepalived` on `kirby`.
5. Confirm the VIP migrates to `yoshi`.
6. Confirm OIDC discovery and LDAPS work without changing local DNS.

## Rollback

If the VIP introduces instability:

1. Disable `keepalived`.
2. Revert Blocky mappings to the phase 1 manual host-IP approach.
3. Rebuild both hosts.

The phase 1 design remains a safe fallback and should be preserved until the VIP path is proven reliable.
