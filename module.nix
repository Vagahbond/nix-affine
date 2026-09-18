{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.affine-server;

  externalUrl = "${if cfg.https then "https" else "http"}://${cfg.domain}";

  databaseUrl =
    if cfg.database.createLocally then
      "postgresql://${cfg.database.user}@/${cfg.database.name}?host=${cfg.database.host}"
    else if cfg.database.passwordFile == null then
      "postgresql://${cfg.database.user}@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}"
    else
      null;

  staticEnvironment = {
    AFFINE_CONFIG_PATH = "${cfg.dataDir}/config";
  }
  // cfg.extraEnvironment;

  needsRuntimeSecretsFile =
    (cfg.database.passwordFile != null) || (cfg.mailer.enable && cfg.mailer.passwordFile != null);
in
{
  options.services.affine-server = import ./options.nix { inherit lib pkgs; };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.database.createLocally -> cfg.database.passwordFile == null;
        message = "services.affine-server.database.passwordFile must not be set when database.createLocally is true.";
      }
      {
        assertion = !cfg.mailer.enable || cfg.mailer.passwordFile != null || cfg.environmentFile != null;
        message = "services.affine-server.mailer.enable requires mailer.passwordFile or a manually provided environmentFile with AFFINE_MAILER_PASSWORD.";
      }
    ];

    users = {
      users.${cfg.user} = {
        isSystemUser = true;
        inherit (cfg) group;
        home = cfg.dataDir;
      };

      groups.${cfg.group} = { };
    };

    services = {
      postgresql = lib.mkIf cfg.database.createLocally {
        ensureDatabases = [ cfg.database.name ];
        ensureUsers = [
          {
            name = cfg.database.user;
            ensureDBOwnership = true;
          }
        ];
      };

      nginx = lib.mkIf cfg.nginx.enable {
        enable = true;
        virtualHosts.${cfg.domain} = {
          enableACME = cfg.nginx.enableACME;
          forceSSL = cfg.nginx.enableACME;

          locations."/" = {
            proxyPass = "http://${cfg.host}:${toString cfg.port}";
            proxyWebsockets = true;
          };
        };
      };

      redis.servers.affine = lib.mkIf cfg.redis.createLocally {
        enable = true;
        port = cfg.redis.port;
        bind = cfg.redis.host;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd = {
      tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
        "d ${cfg.dataDir}/config 0750 ${cfg.user} ${cfg.group} - -"
        "d ${cfg.dataDir}/storage 0750 ${cfg.user} ${cfg.group} - -"
      ];

      services.affine-server = {
        description = "AFFiNE self-hosted server";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network.target"
          (lib.mkIf cfg.database.createLocally "postgresql.service")
          (lib.mkIf cfg.redis.createLocally "redis-affine.service")
        ];
        wants = [
          (lib.mkIf cfg.database.createLocally "postgresql.service")
          (lib.mkIf cfg.redis.createLocally "redis-affine.service")
        ];

        environment = staticEnvironment;

        serviceConfig = {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.dataDir;
          ExecStart = "${cfg.package}/bin/affine-server";
          Restart = "on-failure";
          RestartSec = "5s";

          RuntimeDirectory = "affine-server";
          RuntimeDirectoryMode = "0700";
        };
      };
    };
  };
}
