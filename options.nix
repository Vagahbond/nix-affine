{ lib, pkgs }:

with lib;

{
  enable = mkEnableOption "AFFiNE self-hosted server";

  package = mkOption {
    type = types.package;
    default = pkgs.affine-server;
    defaultText = literalExpression "pkgs.affine-server";
    description = "The affine-server package to run.";
  };

  user = mkOption {
    type = types.str;
    default = "affine";
    description = "User account under which affine-server runs.";
  };

  group = mkOption {
    type = types.str;
    default = "affine";
    description = "Group under which affine-server runs.";
  };

  dataDir = mkOption {
    type = types.path;
    default = "/var/lib/affine";
    description = "Directory holding affine-server's persistent config and storage.";
  };

  domain = mkOption {
    type = types.str;
    example = "affine.example.com";
    description = "Public domain name affine-server is served under.";
  };

  host = mkOption {
    type = types.str;
    default = "127.0.0.1";
    description = "Address affine-server listens on.";
  };

  port = mkOption {
    type = types.port;
    default = 3010;
    description = "Port affine-server listens on.";
  };

  https = mkOption {
    type = types.bool;
    default = true;
    description = "Whether the public-facing URL uses https (used for AFFINE_SERVER_HTTPS and building the external URL).";
  };

  openFirewall = mkOption {
    type = types.bool;
    default = false;
    description = "Whether to open the firewall for the configured port.";
  };

  environmentFile = mkOption {
    type = types.nullOr types.path;
    default = null;
    example = "/run/secrets/affine.env";
    description = ''
      Path to an EnvironmentFile (in the systemd sense) holding secrets such as
      `DATABASE_URL` (when not using a locally managed database), `AFFINE_MAILER_PASSWORD`,
      OAuth client secrets, or a custom `AFFINE_SERVER_JWT_SECRET`.
      Kept out of the Nix store and out of `environment`.
    '';
  };

  extraEnvironment = mkOption {
    type = types.attrsOf types.str;
    default = { };
    example = { AFFINE_INDEXER_ENABLED = "true"; };
    description = "Extra, non-secret environment variables passed to affine-server.";
  };

  database = {
    createLocally = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to create and use a local PostgreSQL database via NixOS' postgresql module.";
    };

    host = mkOption {
      type = types.str;
      default = "/run/postgresql";
      description = "Database host (or unix socket directory) affine-server connects to.";
    };

    port = mkOption {
      type = types.port;
      default = 5432;
      description = "Database port.";
    };

    name = mkOption {
      type = types.str;
      default = "affine";
      description = "Database name.";
    };

    user = mkOption {
      type = types.str;
      default = "affine";
      description = "Database user.";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File containing the database password, read at service start.
        Leave unset when `createLocally` is true, since the local database
        is configured to authenticate via the unix socket peer instead.
      '';
    };
  };

  redis = {
    createLocally = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to create and use a local Redis instance via NixOS' redis module.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Redis host affine-server connects to.";
    };

    port = mkOption {
      type = types.port;
      default = 6379;
      description = "Redis port.";
    };
  };

  mailer = {
    enable = mkEnableOption "outgoing mail support for affine-server";

    host = mkOption {
      type = types.str;
      example = "smtp.example.com";
      description = "SMTP host used to send mail.";
    };

    port = mkOption {
      type = types.port;
      default = 587;
      description = "SMTP port.";
    };

    user = mkOption {
      type = types.str;
      example = "affine@example.com";
      description = "SMTP username.";
    };

    sender = mkOption {
      type = types.str;
      example = "affine@example.com";
      description = "Address mail is sent from.";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the SMTP password, read at service start.";
    };
  };

  nginx = {
    enable = mkEnableOption "an nginx virtual host for affine-server";

    enableACME = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to request an ACME certificate for the virtual host.";
    };
  };
}
