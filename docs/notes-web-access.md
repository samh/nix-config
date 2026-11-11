# Browser Access to Obsidian Notes

This document compares ways to read and edit the existing Obsidian vaults
from a browser without installing Obsidian or configuring Syncthing on the
visiting machine. Syncthing would continue to serve the usual devices.
Authentication should use the existing Kanidm deployment where possible.
Copying text into and out of notes is a core requirement.

Status: options reviewed on 2026-11-10 against the checked-in configuration
and upstream documentation. The code-server implementation was subsequently
deployed on Yoshi, with login and editor loading confirmed on 2026-11-11.
See [Notes Editor on Yoshi](notes-code-server.md) for its validation status.
The other options remain comparisons rather than tested deployments.

## Existing Setup

Both [Yoshi](../hosts/yoshi/syncthing.nix) and
[Kirby](../hosts/kirby/syncthing.nix) are configured to synchronize:

- `~/Notes/Notes-Shared`
- `~/Notes/Notes-Personal`

Kirby also has a [bidirectional notes-history bridge](../hosts/kirby/notes-history.md)
between those working directories and the Gitea repositories
`samh/notes-shared` and `samh/notes-personal`. Git metadata lives outside the
Syncthing folders. The bridge runs every 10 minutes with up to two minutes
of randomized delay and uses conflict branches and PRs when both sides change.

Kirby is therefore a natural place to host a web editor: it already has both
vaults and the history integration. This is a configuration-based assessment;
service health and repository contents have not been checked remotely.

The [shared authentication documentation](auth-oidc.md) and
[Kanidm module](../include/kanidm-auth.nix) describe the existing identity
provider and client provisioning. The shared issuer host is
`sso.hartsfield.xyz`; each application gets its own OIDC client.

## Comparison

| Option | Editing experience | Kanidm approach | Main consideration |
| --- | --- | --- | --- |
| FileBrowser Quantum | File browser, text editor, Markdown preview | Native OIDC | Simple occasional access; limited Obsidian semantics |
| SilverBullet | Dedicated notes app with live preview, wiki links, backlinks, and search | Native OIDC in current multi-space mode | Rich notes UI; synchronizes the space into browser storage |
| Gitea | Rendered Markdown, source editing, and commits | Native OIDC | Existing infrastructure; timer delay and Git conflict workflow |
| Obsidian through Selkies | Actual Obsidian streamed into the browser | OAuth2 Proxy with Kanidm | Best Obsidian fidelity; desktop streaming and clipboard bridge |
| code-server | VS Code editor, workspace search, and Markdown preview | OAuth2 Proxy with Kanidm | Strong source editing; includes terminal and extension execution |

The browser editors should support ordinary text selection and keyboard
copy/paste. That is an expectation to verify in the target browsers, not a
tested guarantee. Pasting images and formatted content is a separate test
from copying plain text.

## FileBrowser Quantum

FileBrowser Quantum can expose the existing vault directories as filesystem
sources. Its built-in text editor supports Markdown, and its viewer renders
Markdown with a table of contents. It also provides file browsing and search.
See the [editor and viewer documentation](https://filebrowserquantum.com/en/docs/features/previewing-files/).

This is a good fit for finding a note, copying a passage, making a small edit,
and saving. Writes go directly to the vault files and then propagate through
Syncthing. No Git commit is required for each browser save.

It has [native OIDC authentication](https://filebrowserquantum.com/en/docs/configuration/authentication/oidc/),
including group-based login restrictions. Source permissions must also be
configured: successfully authenticating does not by itself establish which
vault a user may access.

Treat it as a general Markdown editor. Do not assume that Obsidian wiki links,
embeds, Dataview queries, Canvas files, or plugins will behave like they do in
Obsidian. Scope the service to the vault directories rather than the whole
home directory.

### FileBrowser Trial on Yoshi (Deferred)

FileBrowser Quantum is deferred while the Nixpkgs package catches up with
upstream. If revisited, a native Nix package and systemd service are preferred
so updates follow the NixOS configuration; an automatically updated Podman
container is also an acceptable alternative. The proposed sources are
Shared Notes, Personal Notes, and `/storage/Games`.
Yoshi already has the vault copies, nginx, wildcard certificate configuration,
and the mergerfs pool backing `/storage`. Order the service after the required
mounts and verify filesystem permissions before enabling writes.

As checked on 2026-11-10, both package sets pinned by this flake provide
`filebrowser-quantum` version `1.5.2-stable`. The pinned NixOS
`services.filebrowser` module targets the original File Browser and its
configuration format; merely substituting the Quantum package is insufficient.
Use a service configured specifically for Quantum.

Resolve the package version before deployment. Upstream lists releases before
`2.1.0-stable` as affected by an
[archive/symlink file-write escape](https://github.com/gtsteffaniak/filebrowser/security/advisories/GHSA-3j46-5w28-f8p2).
Prefer an updated Nixpkgs package, or a reviewed Nix package backport if the
available package sets still lag. Check other applicable upstream advisories
when selecting the version; this finding is not a complete security audit.
Generate configuration against that release's schema, since the current
documentation describes v2 and differs from the pinned v1 package.

A subsequent live check found that Nixpkgs master and `nixos-unstable` also
still have `1.5.2-stable`, so this is not just a lockfile delay. An
[open update PR](https://github.com/NixOS/nixpkgs/pull/578487), opened on
2026-10-24, targets `2.0.2-stable` and fixes the package's update script.
The PR describes incorrect frontend/dependency hash handling in that script,
as well as build changes required by v2. Its target version still predates
the `2.1.0-stable` fix above. Prefer resolving the update upstream and then
consuming the maintained package rather than committing to an indefinite
local packaging fork. The eventual merge date is unknown.

## SilverBullet

SilverBullet is a dedicated notes application with live Markdown preview,
wiki links, backlinks, attachments, and search. Its spaces are
[directories of Markdown files](https://docs.silverbullet.md/Space.md), and
external tools can modify those files. Each vault could become a separate
space. See its [feature overview](https://silverbullet.md/features).

It offers a more complete notes experience than a file manager or Git web
editor. [Recent link-resolution changes](https://no.silverbullet.md/2-11)
improve compatibility with Obsidian links, but this does not imply support
for Obsidian plugins or every vault convention. SilverBullet also adds its
own configuration pages and potentially library content to a space; trial it
against a copy of a vault first.

Current [SSO documentation](https://docs.silverbullet.md/Single%20Sign-On)
describes generic OIDC in multi-space mode. Kanidm is a candidate provider,
but the pairing must be tested for PKCE, client authentication, signing
algorithms, scopes, and the required verified-email claim. Check that the
selected SilverBullet release includes the documented SSO support.

An important distinction for occasional access is its
[offline-first browser sync](https://docs.silverbullet.md/Sync): SilverBullet
keeps a copy of the space in browser storage. There is no sync client to
install, but it still downloads and synchronizes the space. On a borrowed
machine, account for that local copy and verify how to clear it; do not assume
that signing out removes cached notes.

## Existing Gitea

The configured repositories are available at:

- [notes-shared](https://gitea.kirby.hartsfield.xyz/samh/notes-shared)
- [notes-personal](https://gitea.kirby.hartsfield.xyz/samh/notes-personal)

Gitea can provide rendered Markdown browsing and source edits committed
through its web interface. The existing notes-history bridge then pulls
changes into Kirby's vaults, and Syncthing distributes them to other devices.
This uses the least additional infrastructure.

The tradeoff is that browser edits are Git changes rather than immediate
filesystem saves. Propagation follows the configured timer, and concurrent
changes can require resolving a conflict PR. The latest desktop changes may
also take a timer cycle to appear in Gitea. Follow the
[notes-history workflow](../hosts/kirby/notes-history.md) for conflict handling.

Gitea supports [native OIDC login](https://docs.gitea.com/administration/authentication/).
No Gitea client is declared in the current Kanidm module, and the
[Gitea module](../hosts/kirby/gitea.nix) does not declare an OIDC source.
An authentication source may nevertheless exist in Gitea's database from UI
configuration; inspect that before adding one. Link the Kanidm identity to
the intended existing Gitea account and preserve private repository access.

## Obsidian Through Selkies

The [LinuxServer Obsidian container](https://docs.linuxserver.io/images/docker-obsidian/)
runs the actual desktop application and streams it to a browser through
Selkies. Mounting the vault directories gives Obsidian access to the same
files used by Syncthing.

This has the strongest fidelity for Obsidian-specific editing, rendering,
and plugins. It also requires a persistent desktop application session and
more resources than a basic web file editor. Separate browser logins do not
automatically create isolated Obsidian desktop sessions.

Selkies supports clipboard transfer in both directions, with automatic
transfer and a manual sidebar clipboard box. Image transfer has separate
controls. Browser permissions and behavior affect the experience, so test
the actual browsers and content types before selecting it. See the
[clipboard configuration](https://docs.linuxserver.io/selkies/user-guide/configuration/).

Use an authentication proxy connected to Kanidm rather than relying on the
container's basic authentication for external access. The image includes
terminal access and passwordless sudo inside the container; isolate it and
expose only the required vault and application data. The container's
documentation explains its access and isolation considerations.

## code-server

The current implementation is a native code-server service on Yoshi for
the two note vaults only. See [Notes Editor on Yoshi](notes-code-server.md)
for authentication, systemd isolation, validation, and deployment details.
Games is excluded from this trial.

code-server provides VS Code in a browser. Open the two existing vault
directories as workspace folders. Saving edits changes the live files on
Kirby, which Syncthing distributes without waiting for the Gitea bridge.

It provides file navigation, quick opening, workspace search, and Markdown
source editing. VS Code's Markdown tooling includes side-by-side preview,
heading navigation, and link completion. See the
[Markdown documentation](https://code.visualstudio.com/docs/languages/markdown).

Copy/paste takes place through the browser editor, avoiding the streamed
desktop's clipboard bridge. Browser permissions and reserved shortcuts can
still matter; verify editor copy/paste over HTTPS. VS Code documents these
[browser considerations](https://code.visualstudio.com/docs/remote/vscode-web#_additional-browser-setup).

Obsidian plugins do not run here. Wiki-link navigation, backlinks, or special
rendering may be available through VS Code extensions, but availability and
compatibility need checking. code-server uses Open VSX by default, as
described in its [platform comparison](https://coder.com/docs/user-guides/workspace-access/code-server).

code-server supports external authentication through proxies such as
OAuth2 Proxy; see its [access guide](https://coder.com/docs/code-server/guide).
This would add a component between nginx and code-server to handle Kanidm
login.

The principal operational consideration is execution access. code-server
includes a terminal and can execute extensions. Selecting a workspace folder
does not restrict filesystem access to that folder. Run it as a dedicated
unprivileged service with explicit filesystem restrictions, or in an isolated
container with only the vaults and its own settings exposed. Hiding the
terminal UI is not an isolation boundary.

## Deployment Shape and Authentication

For a service with native OIDC, nginx can proxy HTTPS traffic directly to the
application, which handles login through Kanidm. For code-server or streamed
Obsidian, the proposed arrangement is:

```text
Browser -> nginx HTTPS -> OAuth2 Proxy -> application
                                |
                                +-----> Kanidm
```

Kanidm documents an [OAuth2 Proxy integration](https://kanidm.github.io/kanidm/master/integrations/oauth2/examples.html#oauth2-proxy).
In either arrangement:

- Use the shared Kanidm hostname and a separate application client, storing
  secrets through the repository's SOPS workflow.
- Bind the backend to localhost or a private container network. Authenticate
  all application routes, including APIs and WebSockets, without a directly
  accessible backend that bypasses login.
- Keep Personal and Shared permissions distinct. An account allowed to use
  the application should not automatically gain access to both vaults.
- Give the service only the filesystem access needed for its vaults and
  application state. Arrange ownership or ACLs so Syncthing can still read
  and update files created by the web editor.
- Decide how visiting machines reach the service: LAN, VPN, or external
  HTTPS. Authentication does not by itself provide network reachability.

## Recommendation and Trial Criteria

FileBrowser Quantum is the simplest dedicated option for occasional file
access. code-server is a strong alternative when source editing, search, and
the VS Code interface are desirable. SilverBullet is the richer notes-app
option if its conventions and browser caching fit the workflow. Gitea is
useful immediately if the bridge is healthy and timer-based propagation is
acceptable. Streamed Obsidian is most attractive when its plugins or exact
rendering are essential.

Before choosing or deploying an option:

1. Trial it against a copy of a representative vault. Check links, front
   matter, attachments, and any Obsidian-specific content that matters.
2. Test plain text copy/paste in both directions in the intended browsers.
   Test image paste separately if needed.
3. Verify Kanidm login, denied access for unauthorized accounts, and separate
   Personal/Shared permissions. For an auth proxy, check API and WebSocket
   access as well as the landing page.
4. Verify a browser save reaches Syncthing peers, and a peer edit appears in
   the browser. Check new-file permissions and avoid stale open buffers.
5. Check concurrent-edit behavior and recovery through existing notes
   history. Syncthing remains file synchronization, not collaborative editing.
6. Confirm what remains in browser storage after logout, especially for
   SilverBullet and borrowed machines.

Keep the existing notes-history integration authoritative for Git history.
If enabling another application's Git features, first reconcile them with
that bridge rather than having two independent Git managers operate on the
same vault.
