{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.services.affine-server;

  redisServerName = "redis-affine";
in
{
  options.services.affine-server = import ./options.nix { inherit lib pkgs; };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.settings.server.host != null;
        message = "AFFiNE server host must be set to a FQDN.";
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
        "d ${cfg.dataDir}/config 0750 ${cfg.user} ${cfg.group} - -"
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
            (lib.mkIf cfg.database.createLocally systemdCfg.postgresql.name)
            (lib.mkIf cfg.redis.createLocally systemdCfg.${redisServerName}.name)
          ];

          wants = [
            (lib.mkIf cfg.database.createLocally systemdCfg.postgresql.name)
            (lib.mkIf cfg.redis.createLocally systemdCfg.${redisServerName}.name)
          ];

          inherit (cfg) environmentFile;

          environment = {
            REDIS_SERVER_HOST = cfg.redis.host;
            REDIS_SERVER_PORT = toString cfg.redis.port;

            DATABASE_URL = "postgresql://${cfg.database.user}:${cfg.database.password}@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}";

          };

          preStart = ''
            # https://github.com/toeverything/AFFiNE/blob/d897bb3d84099e54a6b3c0bd5f4265f8aa87d190/packages/backend/server/src/base/config/register.ts#L284
            ${utils.genJqSecretsReplacementSnippet cfg.settings "/run/affine/config.json"}

            # Setup paths
            ln -sTf /run/affine/config.json "${config.users.users.${cfg.user}.home}/.affine/config/config.json"

            ${cfg.package}/bin/affine-server-predeploy
          '';

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
