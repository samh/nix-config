# The service and VM test use the same systemd isolation settings.
{
  pkgs,
  lib ? pkgs.lib,
  sharedDir,
  personalDir,
  stateDir,
  socketDir,
  ownerUid ? 1000,
}: let
  tools = [pkgs.bashInteractive pkgs.coreutils pkgs.ripgrep];
  workspace = pkgs.writeText "notes.code-workspace" (builtins.toJSON {
    folders = [
      {
        name = "Shared Notes";
        path = "/notes/shared";
      }
      {
        name = "Personal Notes";
        path = "/notes/personal";
      }
    ];
    settings = {
      "remote.autoForwardPorts" = false;
      "extensions.autoCheckUpdates" = false;
      "extensions.autoUpdate" = false;
      "telemetry.telemetryLevel" = "off";
      "terminal.integrated.defaultProfile.linux" = "bash";
      "terminal.integrated.profiles.linux".bash.path = "${pkgs.bashInteractive}/bin/bash";
      "files.watcherExclude" = {
        "**/.obsidian/**" = true;
        "**/.stversions/**" = true;
        "**/.stfolder/**" = true;
      };
      "search.exclude" = {
        "**/.obsidian/**" = true;
        "**/.stversions/**" = true;
      };
    };
  });
  root = pkgs.runCommand "notes-code-server-root" {} ''
    mkdir -p "$out"/{bin,etc,dev,proc,sys,nix/store,notes/shared,notes/personal,tmp,var/tmp,run/notes-code-server,var/lib/notes-code-server}
    ln -s ${pkgs.bashInteractive}/bin/bash "$out/bin/sh"
    cp ${workspace} "$out/etc/notes.code-workspace"
    echo 'coder:x:${toString ownerUid}:100:Notes editor:${stateDir}:${pkgs.bashInteractive}/bin/bash' > "$out/etc/passwd"
    printf 'root:x:0:\nusers:x:100:\n' > "$out/etc/group"
    echo 'passwd: files' > "$out/etc/nsswitch.conf"
    echo 'group: files' >> "$out/etc/nsswitch.conf"
  '';
in {
  inherit root;
  environment = {
    HOME = stateDir;
    USER = "coder";
    LOGNAME = "coder";
    SHELL = "${pkgs.bashInteractive}/bin/bash";
    PATH = lib.mkForce (lib.makeBinPath tools);
    LANG = "C.UTF-8";
    TMPDIR = "/tmp";
    XDG_CONFIG_HOME = "${stateDir}/.config";
    XDG_CACHE_HOME = "${stateDir}/.cache";
    XDG_DATA_HOME = "${stateDir}/.local/share";
  };
  serviceConfig = {
    ExecStart = lib.escapeShellArgs [
      "${lib.getExe pkgs.code-server}"
      "--auth=none"
      "--socket=${socketDir}/editor.sock"
      "--socket-mode=0660"
      "--user-data-dir=${stateDir}/data"
      "--extensions-dir=${stateDir}/extensions"
      "--disable-telemetry"
      "--disable-update-check"
      "--disable-proxy"
      "/etc/notes.code-workspace"
    ];
    RootDirectory = root;
    MountAPIVFS = true;
    BindLogSockets = false;
    # Do not copy submounts under RootDirectory back into the sandbox via its
    # own store path; that would create aliases around the path restrictions.
    BindReadOnlyPaths = ["/nix/store:/nix/store:norbind"];
    BindPaths = ["${sharedDir}:/notes/shared:norbind" "${personalDir}:/notes/personal:norbind"];
    StateDirectory = "notes-code-server";
    StateDirectoryMode = "0700";
    RuntimeDirectory = "notes-code-server";
    RuntimeDirectoryMode = "0750";
    WorkingDirectory = "/notes";
    UMask = "0022";
    Restart = "on-failure";
    RestartSec = 5;
    SetLoginEnvironment = false;
    UnsetEnvironment = ["SSH_AUTH_SOCK" "DBUS_SESSION_BUS_ADDRESS" "NIX_REMOTE" "NOTIFY_SOCKET"];
    NoNewPrivileges = true;
    CapabilityBoundingSet = "";
    AmbientCapabilities = "";
    ProtectSystem = "strict";
    ReadWritePaths = ["+${stateDir}" "+${socketDir}" "+/notes/shared" "+/notes/personal"];
    # Vaults also contain plugins that run outside this sandbox on other peers.
    # Require these existing directories so a missing mask fails closed.
    InaccessiblePaths = ["+/notes/shared/.obsidian" "+/notes/personal/.obsidian"];
    PrivatePIDs = true;
    PrivateUsers = true;
    PrivateNetwork = true;
    PrivateIPC = true;
    PrivateTmp = "disconnected";
    PrivateDevices = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    RestrictNamespaces = true;
    # libuv enumerates interfaces using netlink/IP sockets. These remain in
    # the private network namespace, with all IP traffic denied by the cgroup.
    RestrictAddressFamilies = ["AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6"];
    IPAddressDeny = "any";
    RestrictSUIDSGID = true;
    RestrictRealtime = true;
    LockPersonality = true;
    KeyringMode = "private";
    SystemCallArchitectures = "native";
    SystemCallFilter = ["~@mount" "~@reboot" "~@swap" "~@raw-io" "~@obsolete" "~ptrace" "~process_vm_readv" "~process_vm_writev"];
    MemoryMax = "2G";
    TasksMax = 256;
  };
}
