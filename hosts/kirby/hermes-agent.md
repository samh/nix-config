# Hermes Agent on Kirby

## Current setup

Hermes is managed by the upstream NixOS module through the shared flake.
See [`hermes-agent.nix`](./hermes-agent.nix) for the service configuration
and [`flake.lock`](../../flake.lock) for the upstream revision. Only Kirby
imports the module. Normal rebuilds of other hosts skip the Hermes input,
while `just up` includes it in the shared lock update.
Hermes follows the shared `nixpkgs-unstable` and `home-manager` inputs to
avoid additional copies of their source trees. Stable nixpkgs failed to
evaluate with this Hermes revision. The shared unstable package set
evaluated successfully, but build compatibility still needs verification.
If upstream changes introduce a package compatibility problem, restore
Hermes' separate nixpkgs pin and re-evaluate.

The initial configuration evaluated successfully, including the complete
Kirby system derivation, the CLI package, and the dashboard unit. Building,
activating on Kirby, signing in, and testing an actual model request are
still pending.

| Setting | Value |
| --- | --- |
| Deployment | Native NixOS systemd services |
| Service user and group | `hermes` |
| State directory | `/var/lib/hermes` |
| `HERMES_HOME` | `/var/lib/hermes/.hermes` |
| Default workspace | `/var/lib/hermes/workspace` |
| Provider | `openai-codex` (ChatGPT subscription OAuth) |
| Default model | `gpt-6.2-sol`, subject to account availability |
| Gateway | `hermes-agent.service` |
| Web dashboard and Desktop backend | `hermes-backend.service`, `127.0.0.1:9119` |

The gateway and dashboard run as separate processes using the same state.
The dashboard is initially accessible through an SSH tunnel. Hermes uses
its native terminal backend and the permissions of the service user for
local tool execution.

## First deployment and login

From the configuration checkout on the workstation, rebuild and switch
Kirby using the existing remote deployment script.

```bash
just rebuild-host kirby switch
```

The script syncs the repository to Kirby and runs the rebuild there. The
first build may take some time to fetch or compile the Hermes dependencies.

SSH to Kirby and check the installation:

```bash
ssh kirby
systemctl status hermes-agent.service hermes-backend.service
sudo -iu hermes hermes --version
```

Sign in as the service user to give Hermes access to the ChatGPT account:

```bash
sudo -u hermes -H env HERMES_HOME=/var/lib/hermes/.hermes \
  /run/current-system/sw/bin/hermes auth add openai-codex
```

Open the verification URL printed by Hermes in a browser on the workstation,
enter the device code, and authorize the intended ChatGPT account. The
device-code flow works over SSH without a callback tunnel. If device-code
login is unavailable, see the upstream [OAuth over SSH guide][oauth-ssh]
for the loopback browser login flow on port 1455.

Verify the authentication status without displaying the credential file:

```bash
sudo -u hermes -H env HERMES_HOME=/var/lib/hermes/.hermes \
  /run/current-system/sw/bin/hermes auth status openai-codex
```

If the configured model is unavailable to the account, change
`services.hermes-agent.settings.model.default` in the Nix module and
rebuild. Upstream lists `gpt-6-sol` as a fallback for accounts without
GPT-6.2 access. Subscription limits and model availability depend on the
account. Additional tools may require their own credentials.

## Initial operation

### CLI and TUI

The module's `addToSystemPackages` option installs the same Hermes package
used by the service to `/run/current-system/sw/bin/hermes` and exports
`HERMES_HOME` system-wide. The state and OAuth files belong to the `hermes`
account, so use that identity for interactive operations as well.

On Kirby, an interactive login shell as the service user is convenient:

```bash
sudo -iu hermes
cd /var/lib/hermes/workspace
hermes --tui
```

Exit the TUI and then the service-user shell when finished. The CLI works
with the same persistent state as the gateway and dashboard. A normal
workstation shell has its own local environment, so run the commands on
Kirby when operating this installation.

### Web dashboard

From the workstation:

```bash
ssh -N -L 9119:127.0.0.1:9119 kirby
```

Open <http://localhost:9119/> and keep the SSH session open while using the
dashboard. The tunnel carries traffic over SSH to the loopback listener.
The loopback dashboard grants access to the service's state and tools to
clients that can reach it, so keep direct access limited to trusted users.

After login, try a short chat and confirm the currently selected model,
session history, and service logs. Check the same session history from the
CLI if desired.

### Service administration and updates

On Kirby:

```bash
systemctl status hermes-agent.service hermes-backend.service
sudo journalctl -f -u hermes-agent.service -u hermes-backend.service
sudo systemctl restart hermes-agent.service hermes-backend.service
```

Restart both units when a config change needs to be picked up by their
running processes. If authentication expires or is revoked, repeat the
OAuth login as the service user.

The NixOS module marks this installation as managed. Make declarative
settings changes in `hermes-agent.nix`, and use the systemd units for
service lifecycle management. Commands such as `hermes setup`,
`hermes config set`, and `hermes gateway install` are blocked in managed
mode. `hermes auth add` remains the supported credential bootstrap.

Update Hermes with the rest of the flake using `just up`, or selectively
refresh the Hermes input from the workstation checkout:

```bash
nix flake update hermes-agent
nix flake check --no-build
```

Then rebuild Kirby. Upstream Nix support is best-effort, so verify the
package and system evaluation on updates and retain a working system
generation for rollback.

### Persistent state and credentials

The module generates and merges `config.yaml` under `HERMES_HOME`.
Hermes maintains its refreshable OAuth credentials in `auth.json` there,
along with sessions, skills, memory, and other runtime data. These survive
normal rebuilds. Keep the OAuth file private and out of Git and the Nix
store. If additional API keys or service credentials are needed, use
SOPS runtime secret files through `services.hermes-agent.environmentFiles`.

## Potential improvements

### Easier CLI access

Add a clearly named operator command (for example `hermes-kirby`) to enter
the service user's workspace and launch the TUI from Kirby, or connect over
SSH from a workstation. Keep the service identity and its home explicit.
An alias or small script that invokes `sudo` as the `hermes` user would
avoid repeating the login-shell steps. Consider whether a per-user CLI
profile would be preferable if other users need independent agents.

### nginx, HTTPS and Kanidm

Use a hostname such as `hermes.kirby.hartsfield.xyz` with Kirby's existing
wildcard ACME certificate and nginx reverse proxy. Keep the dashboard bound
to loopback and forward the HTTPS endpoint, including WebSocket upgrades.

The pinned Hermes source supports a bundled self-hosted OIDC provider.
Try native dashboard authentication against Kanidm first:

- Configure the nginx virtual host with `forceSSL`, the existing ACME
  certificate (`useACMEHost = config.my.hostDomain`), and
  `proxyWebsockets = true` for the backend on `127.0.0.1:9119`.
- Set `settings.dashboard.public_url` to the final HTTPS URL so Hermes
  recognizes the external hostname and constructs the correct callback.
  Forward the original host and scheme with nginx. Loopback proxies are
  automatically trusted by Hermes.
- Add a dedicated Kanidm OAuth client and access group in
  [`include/kanidm-auth.nix`](../../include/kanidm-auth.nix), using the
  authorization-code/PKCE flow. Register the callback
  `https://hermes.kirby.hartsfield.xyz/auth/callback` and allow only the
  intended operator account. The existing Homarr and Notes Editor
  resources show the repository's Kanidm provisioning conventions.
- Configure `settings.dashboard.oauth.provider = "self-hosted"`,
  `settings.dashboard.oauth.self_hosted.issuer` to the Kanidm discovery
  issuer (`https://sso.hartsfield.xyz/oauth2/openid/<client-id>`), and
  `settings.dashboard.oauth.self_hosted.client_id` to the dedicated client
  ID. Verify compatibility with Kanidm's public PKCE client provisioning.
  If a confidential client is used, verify its support in the chosen
  Hermes revision and supply its secret through SOPS, not Nix settings.
- Test both accepted and denied logins, the OAuth callback, logout,
  browser chat, API requests and WebSocket connections over HTTPS before
  relying on the new endpoint. Verify the backend's Host/Origin checks
  and that unauthorized users cannot access the agent or its tools.

Every authenticated dashboard user has access to the shared agent and its
tools. Restrict the Kanidm application to the intended account. Kanidm
authentication protects dashboard access; the ChatGPT OAuth login still
provides the agent's model credentials independently.

If Hermes' native OIDC integration does not work with Kanidm, consider the
existing [`hosts/yoshi/code-server.nix`](../yoshi/code-server.nix) pattern
using oauth2-proxy and nginx `auth_request`, after checking how it interacts
with Hermes' own authentication gate and WebSocket protocol.

### Other improvements

- Evaluate Hermes' newer gateway-hosted Webapp (`settings.webapp`), which
  may simplify the deployment by using the gateway process for chats.
  Recheck Desktop compatibility before replacing the separate dashboard.
- Add `/var/lib/hermes` to the encrypted Borgmatic backup configuration
  after deciding how to capture consistent SQLite state and protect the
  OAuth credentials. The current Kirby backup list does not include it.
- Consider a smaller Hermes package variant if build times or closure size
  become a problem. Revisit a separate Kirby flake only if maintaining the
  shared lock becomes burdensome.
- Define any additional workspace access, tools, scheduled jobs, or
  messaging integrations as needed, with permissions scoped to the task.

## Upstream references

- [Nix and NixOS setup][nix-setup]
- [Provider configuration and subscription OAuth][providers]
- [OAuth login over SSH][oauth-ssh]
- [Web dashboard and self-hosted OIDC][dashboard]

[nix-setup]: https://hermes-agent.nousresearch.com/docs/getting-started/nix-setup
[providers]: https://hermes-agent.nousresearch.com/docs/integrations/providers
[oauth-ssh]: https://hermes-agent.nousresearch.com/docs/guides/oauth-over-ssh
[dashboard]: https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard#self-hosted-oidc-provider
