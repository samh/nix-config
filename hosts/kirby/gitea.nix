{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.services.gitea;
  srv = cfg.settings.server;
in {
  services.nginx = {
    virtualHosts.${cfg.settings.server.DOMAIN} = {
      forceSSL = true;
      useACMEHost = config.my.hostDomain;
      extraConfig = ''
        client_max_body_size 512M;
      '';
      locations."/".proxyPass = "http://localhost:${toString srv.HTTP_PORT}";
    };
  };

  services.gitea = {
    enable = true;
    database.type = "sqlite3";
    #database.type = "postgres";
    # Enable support for Git Large File Storage
    #lfs.enable = true;
    settings = {
      server = {
        DOMAIN = "gitea.${config.my.hostDomain}";
        # You need to specify this to remove the port from URLs in the web UI.
        ROOT_URL = "https://${srv.DOMAIN}/";
        HTTP_PORT = 3002;
      };
      # You can temporarily allow registration to create an admin user.
      service.DISABLE_REGISTRATION = true;
      security = {
        LOGIN_REMEMBER_DAYS = 90; # default is 31
      };
      # Add support for actions, based on act: https://github.com/nektos/act
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
      # Sending emails is completely optional
      # You can send a test email from the web UI at:
      # Profile Picture > Site Administration > Configuration >  Mailer Configuration
      #      mailer = {
      #        ENABLED = true;
      #        SMTP_ADDR = "mail.example.com";
      #        FROM = "noreply@${srv.DOMAIN}";
      #        USER = "noreply@${srv.DOMAIN}";
      #      };
    };
    #mailerPasswordFile = config.age.secrets.gitea-mailer-password.path;
  };
}
