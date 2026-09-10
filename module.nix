{ config, lib, pkgs, ... }:

with lib;

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
    AFFINE_SERVER_HOST = cfg.host;
    AFFINE_SERVER_PORT = toString cfg.port;
    AFFINE_SERVER_HTTPS = boolToString cfg.https;
    AFFINE_SERVER_EXTERNAL_URL = externalUrl;
    AFFINE_CONFIG_PATH = "${cfg.dataDir}/config";
    AFFINE_STORAGE_PATH = "${cfg.dataDir}/storage";
    REDIS_SERVER_HOST = cfg.redis.host;
    REDIS_SERVER_PORT = toString cfg.redis.port;
  }
  // optionalAttrs (databaseUrl != null) { DATABASE_URL = databaseUrl; }
  // optionalAttrs cfg.mailer.enable {
    AFFINE_MAILER_HOST = cfg.mailer.host;
    AFFINE_MAILER_PORT = toString cfg.mailer.port;
    AFFINE_MAILER_USER = cfg.mailer.user;
    AFFINE_MAILER_SENDER = cfg.mailer.sender;
  }
  // cfg.extraEnvironment;

  needsRuntimeSecretsFile =
    (cfg.database.passwordFile != null)
    || (cfg.mailer.enable && cfg.mailer.passwordFile != null);
in
{
  options.services.affine-server = import ./options.nix { inherit lib pkgs; };

  config = mkIf cfg.enable {
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

    users.users = mkIf (cfg.user == "affine") {
      affine = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
      };
    };

    users.groups = mkIf (cfg.group == "affine") {
      affine = { };
    };

    services.postgresql = mkIf cfg.database.createLocally {
      enable = true;
      ensureDatabases = [ cfg.database.name ];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    services.redis.servers.affine = mkIf cfg.redis.createLocally {
      enable = true;
      port = cfg.redis.port;
      bind = cfg.redis.host;
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    services.nginx = mkIf cfg.nginx.enable {
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

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/config 0750 ${cfg.user} ${cfg.group} - -"
      "d ${cfg.dataDir}/storage 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.affine-server = {
      description = "AFFiNE self-hosted server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "postgresql.service" "redis-affine.service" ];
        ++ optional cfg.database.createLocally "postgresql.service"
        ++ optional cfg.redis.createLocally "redis-affine.service";
      wants = optional cfg.database.createLocally "postgresql.service"
        ++ optional cfg.redis.createLocally "redis-affine.service";

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
      }
      // optionalAttrs needsRuntimeSecretsFile {
        ExecStartPre = "${pkgs.writeShellScript "affine-server-secrets" ''
          set -euo pipefail
          out="/run/affine-server/secrets.env"
          : > "$out"
          ${optionalString (cfg.database.passwordFile != null) ''
            password=$(cat ${escapeShellArg cfg.database.passwordFile})
            echo "DATABASE_URL=postgresql://${cfg.database.user}:$password@${cfg.database.host}:${toString cfg.database.port}/${cfg.database.name}" >> "$out"
          ''}
          ${optionalString (cfg.mailer.enable && cfg.mailer.passwordFile != null) ''
            echo "AFFINE_MAILER_PASSWORD=$(cat ${escapeShellArg cfg.mailer.passwordFile})" >> "$out"
          ''}
          chmod 0600 "$out"
        ''}";
      }
      // optionalAttrs (cfg.environmentFile != null || needsRuntimeSecretsFile) {
        EnvironmentFile =
          optional (cfg.environmentFile != null) cfg.environmentFile
          ++ optional needsRuntimeSecretsFile "/run/affine-server/secrets.env";
      };
    };
  };
}
