{pkgs}: let
  sandbox = import ../hosts/yoshi/code-server-sandbox.nix {
    inherit pkgs;
    sharedDir = "/home/owner/Notes/Shared";
    personalDir = "/home/owner/Notes/Personal";
    stateDir = "/var/lib/notes-code-server";
    socketDir = "/run/notes-code-server";
  };
  # Reuse the production proxy settings with dummy credentials and a discovery
  # override. No real identity provider or successful login is needed to check
  # that unauthenticated HTTP and WebSocket traffic cannot reach the editor.
  production = import ../hosts/yoshi/code-server.nix {
    inherit pkgs;
    lib = pkgs.lib;
    config = {
      my = {
        user = "owner";
        homeDir = "/home/owner";
        hostDomain = "yoshi.test";
        auth.kanidm.ssoHost = "sso.test";
      };
      sops.secrets = {
        "kanidm/oauth2/notes_code_server_client_secret".path = pkgs.writeText "test-client-secret" "test-only";
        "notes-code-server-cookie-secret".path = pkgs.writeText "test-cookie-secret" "01234567890123456789012345678901";
      };
    };
  };
  probe = pkgs.writeText "notes-sandbox-probe.py" ''
    import ctypes
    import errno
    import os
    from pathlib import Path
    import socket
    import subprocess

    assert os.getuid() == 1000
    assert os.getpid() == 1, "private PID namespace missing"
    status = Path("/proc/self/status").read_text()
    assert "CapEff:\t0000000000000000" in status
    assert "NoNewPrivs:\t1" in status
    assert "Seccomp:\t2" in status
    assert "SSH_AUTH_SOCK" not in os.environ
    assert "DBUS_SESSION_BUS_ADDRESS" not in os.environ
    for path in ["/run/secrets", "/home/owner", "/storage", "/run/user",
                 "/run/systemd", "/var/lib/host-secret", "/tmp/host-secret",
                 "/proc/1/root/run/secrets"]:
        assert not Path(path).exists(), f"host path exposed: {path}"

    for name in ["shared", "personal"]:
        note = Path(f"/notes/{name}/edited.md")
        note.write_text(f"edited {name}\n")
        assert note.read_text() == f"edited {name}\n"
        metadata = Path(f"/notes/{name}/.obsidian")
        try:
            list(metadata.iterdir())
            raise AssertionError("Obsidian metadata exposed")
        except PermissionError:
            pass
        try:
            (metadata / "plugin.js").write_text("changed")
            raise AssertionError("desktop plugin was writable")
        except PermissionError:
            pass
    # The root directory is itself in the readable store. Its original empty
    # mount targets must not provide aliases around the /notes restrictions.
    assert not Path("${sandbox.root}/notes/shared/edited.md").exists()
    assert not Path("${sandbox.root}/notes/shared/.obsidian/plugin.js").exists()
    try:
        Path("/notes/shared/escape").write_text("changed")
        raise AssertionError("symlink escaped the filesystem root")
    except OSError as error:
        assert error.errno in [errno.ENOENT, errno.EROFS, errno.EACCES]
    try:
        Path("/etc/unauthorized").write_text("changed")
        raise AssertionError("root filesystem was writable")
    except PermissionError:
        pass
    except OSError as error:
        assert error.errno == errno.EROFS

    Path("/tmp/private-tmp").write_text("private")
    try:
        connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        connection.settimeout(1)
        connection.connect(("192.0.2.1", 80))
        raise AssertionError("IP traffic allowed")
    except OSError as error:
        assert error.errno in [errno.EPERM, errno.EACCES, errno.ENETUNREACH]
    subprocess.run(["${pkgs.nodejs_22}/bin/node", "-e", "require('os').networkInterfaces()"], check=True)
    unix_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    unix_socket.close()
    libc = ctypes.CDLL(None, use_errno=True)
    assert libc.unshare(0x10000000) == -1, "nested user namespace allowed"
    assert ctypes.get_errno() == errno.EPERM
    print("Filesystem, symlink, process, privilege, and network boundaries passed")
  '';
in
  pkgs.testers.runNixOSTest {
    name = "notes-code-server";
    nodes.machine = {lib, ...}: {
      users.users.owner = {
        isNormalUser = true;
        uid = 1000;
      };
      users.groups.notes-code-server = {};
      users.users.nginx.extraGroups = ["notes-code-server"];
      services.nginx = lib.mkMerge [
        production.services.nginx
        {
          enable = true;
          virtualHosts."notes.yoshi.test" = {
            forceSSL = lib.mkForce false;
            useACMEHost = lib.mkForce null;
            # Stub only the auth decision for the successful transport test.
            # The real proxy's unauthenticated rejection is checked separately.
            locations."= /oauth2/auth" = {
              proxyPass = lib.mkForce null;
              extraConfig = lib.mkForce ''
                internal;
                auth_request off;
                if ($http_x_test_auth != allow) { return 401; }
                return 202;
              '';
            };
          };
        }
      ];
      services.oauth2-proxy =
        production.services.oauth2-proxy
        // {
          loginURL = "http://127.0.0.1:9000/authorize";
          redeemURL = "http://127.0.0.1:9000/token";
          extraConfig =
            production.services.oauth2-proxy.extraConfig
            // {
              skip-oidc-discovery = true;
              oidc-jwks-url = "http://127.0.0.1:9000/jwks";
            };
        };
      systemd.services.oauth2-proxy =
        production.systemd.services.oauth2-proxy
        // {
          wantedBy = lib.mkForce [];
        };
      environment.systemPackages = [pkgs.curl];
      systemd.tmpfiles.rules = [
        "d /home/owner/Notes 0755 owner users - -"
        "d /home/owner/Notes/Shared 0755 owner users - -"
        "d /home/owner/Notes/Personal 0755 owner users - -"
        "d /home/owner/Notes/Shared/.obsidian 0755 owner users - -"
        "d /home/owner/Notes/Personal/.obsidian 0755 owner users - -"
        "f /home/owner/Notes/Shared/.obsidian/plugin.js 0644 owner users - unchanged"
        "f /home/owner/Notes/Personal/.obsidian/plugin.js 0644 owner users - unchanged"
        "d /run/secrets 0700 root root - -"
        "f /run/secrets/proxy-secret 0600 root root - test-secret"
        "f /var/lib/host-secret 0600 owner users - unchanged"
        "f /tmp/host-secret 0600 root root - unchanged"
        "L /home/owner/Notes/Shared/escape - - - - /var/lib/host-secret"
      ];
      systemd.services.notes-code-server = {
        inherit (sandbox) environment;
        serviceConfig =
          sandbox.serviceConfig
          // {
            User = "owner";
            Group = "notes-code-server";
          };
      };
      systemd.services.notes-sandbox-probe = {
        environment =
          sandbox.environment
          // {
            SSH_AUTH_SOCK = "/run/user/1000/ssh-agent";
            DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/1000/bus";
          };
        serviceConfig =
          sandbox.serviceConfig
          // {
            User = "owner";
            Group = "notes-code-server";
            Type = "oneshot";
            Restart = "no";
            ExecStart = "${pkgs.python3}/bin/python3 ${probe}";
          };
      };
      virtualisation.memorySize = 3072;
    };
    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl start notes-sandbox-probe.service")
      machine.succeed("grep -qx unchanged /var/lib/host-secret")
      machine.succeed("grep -qx unchanged /home/owner/Notes/Shared/.obsidian/plugin.js")
      machine.succeed("grep -qx unchanged /home/owner/Notes/Personal/.obsidian/plugin.js")
      machine.succeed("grep -qx 'edited shared' /home/owner/Notes/Shared/edited.md")
      machine.succeed("grep -qx 'edited personal' /home/owner/Notes/Personal/edited.md")
      machine.succeed("test $(stat -c %u /home/owner/Notes/Shared/edited.md) = 1000")
      machine.fail("test -e /tmp/private-tmp")
      machine.succeed("systemctl start notes-code-server.service")
      machine.wait_until_succeeds("curl -fsS --unix-socket /run/notes-code-server/editor.sock http://localhost/healthz")
      machine.succeed("curl -fsS --unix-socket /run/notes-code-server/editor.sock http://localhost/ >/dev/null")
      machine.succeed("test $(stat -c %a /run/notes-code-server/editor.sock) = 660")
      machine.fail("su -s /bin/sh nobody -c 'curl -fsS --unix-socket /run/notes-code-server/editor.sock http://localhost/healthz'")
      machine.succeed("systemctl start oauth2-proxy.service")
      machine.wait_for_open_port(4181)
      for path in ["/", "/healthz", "/vscode/", "/proxy/8000/"]:
          status = machine.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' http://127.0.0.1:4181{path}")
          assert status == "302", f"unauthenticated access to {path}: {status}"
      status = machine.succeed("curl -s -o /dev/null -w '%{http_code}' -H 'X-Forwarded-User: owner' -H 'X-Auth-Request-User: owner' -H 'Authorization: Bearer invalid' http://127.0.0.1:4181/")
      assert status == "302", f"spoofed identity headers bypassed login: {status}"
      status = machine.succeed("curl -s -o /dev/null -w '%{http_code}' -H 'Connection: Upgrade' -H 'Upgrade: websocket' http://127.0.0.1:4181/")
      assert status in ["302", "401", "403"], f"unauthenticated WebSocket allowed: {status}"
      machine.wait_for_unit("nginx.service")
      status = machine.succeed("curl -s -o /dev/null -w '%{http_code}' -H 'Host: notes.yoshi.test' http://127.0.0.1/healthz")
      assert status == "307", f"nginx failed to require authentication: {status}"
      # A permitted request must complete an actual WebSocket upgrade through
      # nginx to code-server, not merely return an HTML landing page.
      import json
      commit = json.loads(machine.succeed("${pkgs.code-server}/bin/code-server --version --json").splitlines()[-1])["commit"]
      machine.succeed(f"curl -s --max-time 2 -D /tmp/ws-headers -o /dev/null -H 'Host: notes.yoshi.test' -H 'X-Test-Auth: allow' -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' 'http://127.0.0.1/stable-{commit}?reconnectionToken=test-transport&reconnection=false&skipWebSocketFrames=false' || test $? = 28")
      machine.succeed("grep -q '101 Switching Protocols' /tmp/ws-headers")
    '';
  }
