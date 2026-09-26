{
  lib,
  pkgs,
  utils,
  config,
  ...
}:
let
  cfg = config.services.affine-server;

  redisServerName = "affine";
in
{
  options.services.affine-server = import ./options.nix {
    inherit
      lib
      pkgs
      config
      ;
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.settings.server.host != null;
        message = "AFFiNE server host must be set to a FQDN.";
      }
      {
        assertion = cfg.database.createLocally -> cfg.user == cfg.database.name;
        message = "services.affine-server.user must equal services.affine-server.database.name when database.createLocally is enabled (PostgreSQL peer authentication over the Unix socket).";
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
        enable = true;
        ensureDatabases = [ cfg.database.name ];
        ensureUsers = [
          {
            name = cfg.database.name;
            ensureDBOwnership = true;
          }
        ];
      };

      nginx = lib.mkIf cfg.nginx.enable {
        enable = true;
        virtualHosts.${cfg.settings.server.host} = {
          enableACME = cfg.nginx.enableACME;
          forceSSL = cfg.nginx.enableACME;

          locations."/" = {
            proxyPass = "http://${cfg.settings.server.listenAddr}:${toString cfg.settings.server.port}";
            proxyWebsockets = true;
          };
        };
      };

      redis.servers.${redisServerName} = lib.mkIf cfg.redis.createLocally {
        enable = true;
        port = cfg.redis.port;
        bind = cfg.redis.host;
      };
    };

    systemd = {
      tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
        "d ${cfg.dataDir}/.affine 0750 ${cfg.user} ${cfg.group} - -"
        "d ${cfg.dataDir}/.affine/config 0750 ${cfg.user} ${cfg.group} - -"
        "d ${cfg.dataDir}/storage 0750 ${cfg.user} ${cfg.group} - -"
      ];

      services.affine-server =
        let
          systemdCfg = config.systemd.services;
        in
        {
          description = "AFFiNE self-hosted server";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network.target"
          ]
          ++ lib.optional cfg.database.createLocally systemdCfg.postgresql.name
          ++ lib.optional cfg.redis.createLocally systemdCfg."redis-${redisServerName}".name;

          wants =
            lib.optional cfg.database.createLocally systemdCfg.postgresql.name
            ++ lib.optional cfg.redis.createLocally systemdCfg."redis-${redisServerName}".name;

          environment = {
            REDIS_SERVER_HOST = cfg.redis.host;
            REDIS_SERVER_PORT = toString cfg.redis.port;

            DATABASE_URL =
              if cfg.database.createLocally then
                "postgresql://${cfg.database.name}@localhost:${toString config.services.postgresql.settings.port}/${cfg.database.name}?host=/run/postgresql"
              else
                "postgresql://${cfg.database.user}${
                  lib.optionalString (cfg.database.password != null) ":${cfg.database.password}"
                }@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}";
          };

          preStart = ''
            # https://github.com/toeverything/AFFiNE/blob/d897bb3d84099e54a6b3c0bd5f4265f8aa87d190/packages/backend/server/src/base/config/register.ts#L284
            ${utils.genJqSecretsReplacementSnippet cfg.settings "${
              config.users.users.${cfg.user}.home
            }/.affine/config/config.json"}

            ${cfg.package}/bin/affine-server-predeploy
          '';

          serviceConfig = {
            EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
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
