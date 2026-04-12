{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.my.auth.kanidm;
  inherit (lib) mkEnableOption mkIf mkOption mkMerge types optionalAttrs;

  activeHostIp = config.my.metadata.hosts.${cfg.manualPrimaryHost}.ip_address;
  peerReplOrigin =
    if cfg.peerHost == null
    then null
    else "repl://${cfg.peerHost}.${config.my.baseDomain}:${toString cfg.replicationPort}";
  acmeCertName = cfg.ssoHost;
  isProvisioningNode = config.networking.hostName == cfg.manualPrimaryHost;
in {
  options.my.auth.kanidm = {
    enable = mkEnableOption "replicated Kanidm identity provider";

    manualPrimaryHost = mkOption {
      type = types.str;
      default = "kirby";
      description = "Host name treated as the phase 1 active node for local DNS answers and provisioning.";
    };

    peerHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Peer Kanidm host used for two-node replication.";
    };

    peerReplicationCertificate = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Replication identity certificate copied from the peer via
        `kanidmd show-replication-certificate`. Leave null for the first deploy,
        then set it and rebuild once both nodes have generated their own certs.
      '';
    };

    ssoHost = mkOption {
      type = types.str;
      default = "sso.${config.my.baseDomain}";
      description = "Shared OIDC hostname used by all applications.";
    };

    ldapHost = mkOption {
      type = types.str;
      default = "ldap.${config.my.baseDomain}";
      description = "Shared LDAP hostname used for services that need LDAPS.";
    };

    httpsPort = mkOption {
      type = types.port;
      default = 8443;
      description = "Local HTTPS port used by the Kanidm server behind nginx.";
    };

    ldapPort = mkOption {
      type = types.port;
      default = 636;
      description = "LDAPS port exposed directly by Kanidm.";
    };

    replicationPort = mkOption {
      type = types.port;
      default = 8444;
      description = "Port used by Kanidm node-to-node replication.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = builtins.hasAttr cfg.manualPrimaryHost config.my.metadata.hosts;
          message = "my.auth.kanidm.manualPrimaryHost must be present in include/metadata.toml.";
        }
        {
          assertion = cfg.peerHost == null || builtins.hasAttr cfg.peerHost config.my.metadata.hosts;
          message = "my.auth.kanidm.peerHost must be null or present in include/metadata.toml.";
        }
      ];

      sops.secrets = {
        "kanidm/admin_password" = {
          owner = "kanidm";
          group = "kanidm";
          mode = "0400";
        };
        "kanidm/idm_admin_password" = {
          owner = "kanidm";
          group = "kanidm";
          mode = "0400";
        };
        "kanidm/oauth2/audiobookshelf_client_secret" = {
          owner = "kanidm";
          group = "kanidm";
          mode = "0400";
        };
      };

      users.users.nginx.extraGroups = ["kanidm"];

      networking.firewall.allowedTCPPorts = [
        cfg.ldapPort
        cfg.replicationPort
      ];

      services.blocky.settings.customDNS.mapping = {
        "${cfg.ssoHost}" = activeHostIp;
        "${cfg.ldapHost}" = activeHostIp;
      };

      services.kanidm = {
        package = pkgs.kanidmWithSecretProvisioning_1_9;

        enableServer = true;
        serverSettings =
          {
            bindaddress = "127.0.0.1:${toString cfg.httpsPort}";
            ldapbindaddress = "0.0.0.0:${toString cfg.ldapPort}";
            origin = "https://${cfg.ssoHost}";
            domain = config.my.baseDomain;
            role = "WriteReplica";
            tls_chain = "/var/lib/acme/${acmeCertName}/fullchain.pem";
            tls_key = "/var/lib/acme/${acmeCertName}/key.pem";
            online_backup = {
              path = "/var/lib/kanidm/backups";
              schedule = "15 04 * * *";
              versions = 7;
            };
            replication = {
              origin = "repl://${config.my.hostDomain}:${toString cfg.replicationPort}";
              bindaddress = "0.0.0.0:${toString cfg.replicationPort}";
            };
          }
          // optionalAttrs (peerReplOrigin != null && cfg.peerReplicationCertificate != null) {
            replication.${peerReplOrigin} = {
              type = "mutual-pull";
              partner_cert = cfg.peerReplicationCertificate;
              automatic_refresh = config.networking.hostName != cfg.manualPrimaryHost;
            };
          };
        provision = {
          enable = isProvisioningNode;
          instanceUrl = "https://localhost:${toString cfg.httpsPort}";
          idmAdminPasswordFile = config.sops.secrets."kanidm/idm_admin_password".path;
          adminPasswordFile = config.sops.secrets."kanidm/admin_password".path;

          groups = {
            "homarr-users" = {};
            "homarr-admins" = {};
            "audiobookshelf-users" = {};
            "audiobookshelf-admins" = {};
          };

          systems.oauth2 = {
            homarr = {
              displayName = "Homarr";
              originUrl = "https://homarr.kirby.${config.my.baseDomain}/api/auth/callback/oidc";
              originLanding = "https://homarr.kirby.${config.my.baseDomain}/";
              basicSecretFile = config.sops.secrets."kanidm/oauth2/homarr_client_secret".path;
              preferShortUsername = true;
              scopeMaps = {
                "homarr-users" = ["openid" "email" "profile" "groups_name"];
                "homarr-admins" = ["openid" "email" "profile" "groups_name"];
              };
            };

            audiobookshelf = {
              displayName = "Audiobookshelf";
              originUrl = [
                "https://audiobookshelf.yoshi.${config.my.baseDomain}/auth/openid/callback"
                "audiobookshelf://oauth"
              ];
              originLanding = "https://audiobookshelf.yoshi.${config.my.baseDomain}/";
              basicSecretFile = config.sops.secrets."kanidm/oauth2/audiobookshelf_client_secret".path;
              preferShortUsername = true;
              scopeMaps = {
                "audiobookshelf-users" = ["openid" "email" "profile"];
                "audiobookshelf-admins" = ["openid" "email" "profile"];
              };
              claimMaps.abs_roles = {
                joinType = "array";
                valuesByGroup = {
                  "audiobookshelf-users" = ["user"];
                  "audiobookshelf-admins" = ["admin"];
                };
              };
            };
          };
        };
      };

      services.nginx.virtualHosts."kanidm-sso" = {
        serverName = cfg.ssoHost;
        forceSSL = true;
        useACMEHost = acmeCertName;
        locations."/" = {
          proxyPass = "https://127.0.0.1:${toString cfg.httpsPort}";
          extraConfig = ''
            proxy_ssl_verify off;
          '';
        };
      };
    }
  ]);
}
