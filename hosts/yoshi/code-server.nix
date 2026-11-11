{
  config,
  lib,
  pkgs,
  ...
}: let
  hostname = "notes.${config.my.hostDomain}";
  stateDir = "/var/lib/notes-code-server";
  socketDir = "/run/notes-code-server";
  sharedDir = "${config.my.homeDir}/Notes/Notes-Shared";
  personalDir = "${config.my.homeDir}/Notes/Notes-Personal";
  clientSecret = "kanidm/oauth2/notes_code_server_client_secret";
  sandbox = import ./code-server-sandbox.nix {
    inherit pkgs lib sharedDir personalDir stateDir socketDir;
    ownerUid = config.users.users.${config.my.user}.uid;
  };
in {
  users.groups.notes-code-server = {};
  users.users.nginx.extraGroups = ["notes-code-server"];

  # The editor uses the notes owner's UID to preserve file ownership without
  # recursive ACL changes. Namespaces remove access to the owner's host session.
  systemd.services.notes-code-server = {
    description = "Isolated notes editor";
    wantedBy = ["multi-user.target"];
    unitConfig.RequiresMountsFor = [sharedDir personalDir];
    environment = sandbox.environment;
    serviceConfig =
      sandbox.serviceConfig
      // {
        User = config.my.user;
        Group = "notes-code-server";
      };
  };

  # Nginx authenticates HTTP and WebSockets with an OAuth2 Proxy subrequest. The
  # editor has only a Unix socket and an otherwise disconnected network namespace.
  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    clientID = "notes-code-server";
    oidcIssuerUrl = "https://${config.my.auth.kanidm.ssoHost}/oauth2/openid/notes-code-server";
    clientSecretFile = config.sops.secrets.${clientSecret}.path;
    redirectURL = "https://${hostname}/oauth2/callback";
    scope = "openid email profile";
    email.domains = ["*"];
    httpAddress = "127.0.0.1:4181";
    upstream = ["static://202"];
    reverseProxy = true;
    trustedProxyIP = ["127.0.0.1/32"];
    passAccessToken = false;
    passBasicAuth = false;
    setXauthrequest = true;
    cookie = {
      name = "__Host-notes_session";
      secretFile = config.sops.secrets."notes-code-server-cookie-secret".path;
      secure = true;
      httpOnly = true;
      expire = "8h";
      refresh = "15m";
    };
    extraConfig = {
      code-challenge-method = "S256";
      oidc-groups-claim = "notes_access";
      allowed-group = ["notes-code-server-users"];
      cookie-samesite = "lax";
      skip-provider-button = true;
      pass-user-headers = false;
      pass-authorization-header = false;
      skip-jwt-bearer-tokens = false;
      proxy-websockets = true;
    };
  };

  systemd.services.oauth2-proxy = {
    after = ["notes-code-server.service"];
    wants = ["notes-code-server.service"];
    serviceConfig = {
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      CapabilityBoundingSet = "";
      UMask = "0077";
    };
  };

  sops.secrets = {
    ${clientSecret} = {
      owner = "kanidm";
      group = "kanidm";
      mode = "0400";
    };
    "notes-code-server-cookie-secret" = {
      mode = "0400";
    };
  };

  services.nginx.virtualHosts.${hostname} = {
    forceSSL = true;
    useACMEHost = config.my.hostDomain;
    locations."/" = {
      proxyPass = "http://unix:${socketDir}/editor.sock:";
      proxyWebsockets = true;
      extraConfig = ''
        auth_request /oauth2/auth;
        error_page 401 = @notes_login;
        auth_request_set $notes_cookie $upstream_http_set_cookie;
        add_header Set-Cookie $notes_cookie;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        proxy_buffering off;
      '';
    };
    locations."/oauth2/" = {
      proxyPass = "http://127.0.0.1:4181";
      extraConfig = ''
        proxy_set_header X-Auth-Request-Redirect $scheme://$host$request_uri;
      '';
    };
    locations."= /oauth2/auth" = {
      proxyPass = "http://127.0.0.1:4181/oauth2/auth";
      extraConfig = ''
        internal;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header X-Original-URL $scheme://$host$request_uri;
      '';
    };
    locations."@notes_login".return = "307 /oauth2/start?rd=$scheme://$host$request_uri";
  };
}
