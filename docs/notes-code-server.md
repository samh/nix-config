# Notes Editor on Yoshi

The notes editor uses the Nixpkgs `code-server` package, a systemd sandbox,
and OAuth2 Proxy connected to Kanidm. It exposes the two existing Syncthing
vaults at `https://notes.yoshi.hartsfield.xyz`. Games and the rest of the
home directory are excluded.

Implementation status: deployed; the user confirmed the editor works after
the WebSocket repair on 2026-11-11. Full system builds passed
for Yoshi and Kirby. The VM test passed the sandbox boundaries, editor
startup, and authentication bypass checks. The
full-repository flake check currently fails on Bowser's unrelated broken
`python3.14-posthog` dependency. See the validation section for the targeted
checks; the same failure was reproduced on the unchanged committed
configuration. Live Kanidm login and editor loading have been confirmed;
clipboard and Syncthing round-trip checks have not been explicitly confirmed.

## Configuration

- [Yoshi service](../hosts/yoshi/code-server.nix): native editor, OAuth2 Proxy,
  nginx, and secret declarations.
- [Systemd sandbox](../hosts/yoshi/code-server-sandbox.nix): the filesystem,
  process, user, and network boundaries, shared with the VM test.
- [Kanidm provisioning](../include/kanidm-auth.nix): the `notes-code-server`
  OIDC client and `notes-code-server-users` group.
- [VM test](../tests/notes-code-server.nix): actual sandbox behavior and editor
  startup against temporary vaults.

The package versions follow the existing flake lock. No container image or
separately updated application installation is involved. The editor's update
checks and telemetry are disabled; extension update checks are disabled in
the initial workspace.

## Request Path and Authorization

```text
Browser -> Yoshi nginx HTTPS -> editor Unix socket
                    |
                    +-> OAuth2 Proxy authentication subrequest
                                  |
                                  +-> Kanidm at sso.hartsfield.xyz
```

Nginx checks editor HTTP and WebSocket requests with OAuth2 Proxy before
forwarding them directly to the editor Unix socket. The editor
has no TCP listener, and its Unix socket is accessible to the notes owner,
nginx through its service group, and host root.

OAuth2 Proxy requires membership in `notes-code-server-users`, conveyed in
the client's `notes_access` claim. The Kanidm client grants its scopes to
that group only. PKCE S256 and TLS verification remain enabled. Session
cookies are HTTPS-only, HttpOnly, host-scoped cookies with an eight-hour
lifetime and a fifteen-minute refresh interval. Existing sessions and open
WebSockets are not an instant revocation mechanism.

This is one shared editor session for the trusted notes owner. Every allowed
account receives access to both Personal and Shared Notes and the editor
state. It does not provide per-account vault separation. Keep the access
group limited accordingly.

The OIDC client and cookie secrets are encrypted in `secrets/secrets.yaml`:

- `kanidm/oauth2/notes_code_server_client_secret`
- `notes-code-server-cookie-secret`

Systemd supplies the proxy's secrets through credentials. They are not passed
to the editor or included as plaintext in the Nix store. The client secret
is also available to Kanidm's provisioner on Kirby.

## Systemd Isolation

The editor uses a minimal immutable `RootDirectory`, containing only the
small account files and initial workspace configuration needed to start it.
The following host data is mounted inside it:

| Host path | Editor path | Access |
| --- | --- | --- |
| `~/Notes/Notes-Shared` | `/notes/shared` | Read/write |
| `~/Notes/Notes-Personal` | `/notes/personal` | Read/write |
| `/var/lib/notes-code-server` | Same path | Read/write editor state and extensions |
| `/run/notes-code-server` | Same path | Editor socket |
| `/nix/store` | Same path | Read-only packages and other store contents |

The entire Nix store is readable, including other world-readable store
contents. Do not place plaintext secrets in Nix derivations or configuration.
The host's actual home, SSH agents, D-Bus, Nix daemon socket, service secrets,
and other storage paths are absent. A symlink in a vault resolves inside this
restricted filesystem, not against the host root.

The existing `.obsidian` directory in each vault is masked with
`InaccessiblePaths`. This prevents reading plugin settings or modifying
plugins and configuration that Syncthing would propagate to desktop Obsidian.
These directories must exist: startup fails if a required mask cannot be
applied. They were checked present on Yoshi. This is an OS restriction, not
just a file-tree exclusion.

`PrivatePIDs`, `PrivateUsers`, `PrivateNetwork`, and `PrivateIPC` separate the
editor from host processes, namespace capabilities, network, and IPC.
`RestrictAddressFamilies` allows Unix, netlink, and IP sockets so Node can
enumerate interfaces. `IPAddressDeny=any` blocks IP traffic, and the private
network namespace has no host interfaces. Nginx reaches the filesystem Unix
socket without giving the editor host network access. `PrivateDevices` supplies minimal devices, and temporary files are
private.

The editor has no Linux capabilities, cannot gain privilege through setuid
programs, and cannot create further namespaces or perform mount operations.
The root filesystem is read-only; only the vaults, editor state, socket
directory, and private temporary storage are writable. Memory and task limits
bound resource use. These restrictions apply to terminals and server-side
extensions as well as the main editor process.

The service runs with the notes owner's host UID so new files remain owned by
that user and Syncthing needs no recursive ACL changes. Its private PID
namespace and restricted filesystem prevent access to the owner's host
processes and session sockets. New files use the editor's service group and
a `0022` umask.

The application can modify or delete note content in both exposed vaults;
the masked Obsidian configuration directories are excluded.
Existing Syncthing and notes history remain the recovery mechanisms. Files
outside those mounts are protected by the sandbox. Network restrictions on
the server do not prevent an authenticated browser from displaying or copying
notes, which is the intended purpose of the service.

Edited notes are still consumed by other applications. The sandbox does not
sanitize Markdown or code blocks that desktop plugins may execute. Restrict
access to the trusted notes owner even with Obsidian's configuration masked.

## Editor Behavior

The initial workspace contains Shared Notes and Personal Notes. It includes
the built-in Markdown editor and preview, file search, and a Bash terminal.
The terminal has Bash, coreutils, and ripgrep on its default PATH; other
readable Nix store programs are not a security boundary.

There is no server network access, including to the LAN or host loopback.
Online extension installation, Git remotes, and tools that fetch remote
content will fail. Local VSIX installation remains possible. Code-server's
port-proxy routes are disabled. Changes to workspace preferences cannot
remove the systemd restrictions.

Saves go directly into the Syncthing vaults. Kirby's existing notes-history
bridge continues to record them; no additional Git manager is configured.
Avoid editing the same note concurrently in different applications or leaving
stale unsaved buffers open.

## Validation

Run the sandbox VM test from the repository root:

```sh
nix build --impure --no-link --expr '
  let f = builtins.getFlake ("path:" + toString ./.);
  in import ./tests/notes-code-server.nix {
    pkgs = f.nixosConfigurations.yoshi.pkgs;
  }
'
```

The test runs the same sandbox settings used by the editor. It checks writes
to both vaults and file ownership; denied host-file and symlink access;
process, capability, environment, and network restrictions; private temporary
storage; actual code-server startup and HTTP responses through its Unix
socket; and denial of socket access to an unrelated local user. It also checks
that Obsidian metadata and plugin files cannot be read or changed, and that
the production proxy settings reject unauthenticated HTTP, WebSocket, and
forged-identity-header requests. A discovery override and dummy credentials
are used in that proxy test; it does not test a real Kanidm login. The nginx transport test stubs only
the authentication decision and verifies a successful WebSocket upgrade to
code-server. Interface enumeration is tested inside the actual sandbox.

Evaluate/build the affected hosts and run the existing repository checks:

```sh
nix flake check --no-build path:.
nix build --no-link path:.#nixosConfigurations.yoshi.config.system.build.toplevel
nix build --no-link path:.#nixosConfigurations.kirby.config.system.build.toplevel
scripts/check-host-updates.sh --hosts yoshi,kirby --strict
```

`path:.` includes new files before they have been added to Git. Normal Git
flake references require new imported files to be tracked.

## Deployment and Browser Checks

1. Deploy Kirby's configuration first to provision the OIDC client, access
   group, and client secret. Yoshi's service and nginx configuration can then
   be deployed with the repository's usual rebuild workflow.
2. In Kanidm, add the intended existing account to `notes-code-server-users`.
   Group membership is preserved across provisioning runs. The account must
   have an email address usable by the OIDC provider.

   ```sh
   kanidm login --name idm_admin
   kanidm group add-members --name idm_admin notes-code-server-users YOUR_KANIDM_USERNAME
   ```

3. Ensure `notes.yoshi.hartsfield.xyz` resolves to Yoshi from the visiting
   machines. The configured wildcard certificate covers the hostname; DNS
   and network reachability must also work from those machines.
4. Verify that a logged-out browser is sent to Kanidm, that an account outside
   the group is denied, and that the intended account reaches the editor.
5. Copy and paste text in both directions and check Markdown preview. Save a
   temporary note in each vault, confirm it reaches another Syncthing device,
   then remove it. Check peer edits appearing in the browser too.
6. Verify the deployed service and proxy logs and run `systemd-analyze security
   notes-code-server.service`. Inspect actual behavior as well as the score;
   it is not a replacement for the boundary test.

The service requires systemd's `PrivatePIDs` support (introduced in version
257). Yoshi was checked running systemd 260.5 during implementation.
