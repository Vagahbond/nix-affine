# Schema available here : https://github.com/toeverything/affine/releases/latest/download/config.schema.json
{
  lib,
  pkgs,
  config,
}:
let
  secret = lib.types.submodule {
    options = {
      _secret = lib.mkOption {
        type = lib.types.externalPath;
        description = "Path to the secret file";
      };
    };
  };

  jsonFormat = pkgs.formats.json { };

  cfg = config.services.affine-server;
in
{
  enable = lib.mkEnableOption "AFFiNE self-hosted server";

  package = lib.mkOption {
    type = lib.types.package;
    description = "The affine-server package to run.";
  };

  nginx = {

    enable = lib.mkEnableOption "an nginx virtual host for affine-server";

    enableACME = lib.mkOption {
      type = lib.types.bool;
      default = cfg.nginx.enable;
      description = "Whether to request an ACME certificate for the virtual host.";
    };
  };

  redis = {
    createLocally = lib.mkEnableOption "a local Redis instance via NixOS' redis module";
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Redis host affine-server connects to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6379;
      description = "Redis port.";
    };
  };

  database = {
    createLocally = lib.mkEnableOption "a local PostgreSQL instance via NixOS' postgresql module";

    name = lib.mkOption {
      type = lib.types.str;
      default = "affine";
      description = "Database name.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = cfg.database.name;
      description = "Database user.";
    };

    password = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "affine";
      description = "Database password.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Database host.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5432;
      description = "Database port.";
    };
  };

  user = lib.mkOption {
    type = lib.types.str;
    default = "affine";
    description = "User account under which affine-server runs.";
  };

  group = lib.mkOption {
    type = lib.types.str;
    default = "affine";
    description = "Group under which affine-server runs.";
  };

  dataDir = lib.mkOption {
    type = lib.types.externalPath;
    default = "/var/lib/affine";
    description = "Directory holding affine-server's persistent config and storage.";
  };

  environmentFile = lib.mkOption {
    type = lib.types.nullOr lib.types.externalPath;
    default = null;
    description = "Path to the environment file (refer to https://docs.affine.pro/self-host-affine/references/environment-variables)";
  };

  settings = lib.mkOption {
    description = ''
      AFFiNE server settings.
          You can specify secret values in this configuration by setting somevalue._secret = "/path/to/file" instead of setting somevalue directly.
          Refer to https://github.com/toeverything/affine/releases/latest/download/config.schema.json
    '';

    type = lib.types.submodule {
      freeformType = jsonFormat.type;

      options = {
        metrics = {
          enabled = lib.mkEnableOption "Enable metric and tracing collection";
        };

        crypto = lib.mkOption {
          type = lib.types.submodule {
            freeformType = jsonFormat.type;
            options = {
              privateKey = lib.mkOption {
                type = lib.types.either secret (lib.types.nullOr lib.types.str);
                description = "The private key for used by the crypto module to create signed tokens or encrypt data.\n@default \"\"\n@environment `AFFINE_PRIVATE_KEY`";
                example = {
                  _secret = "/var/lib/affine/private.key";
                };
              };
            };
          };
        };

        auth = lib.mkOption {
          description = "Configuration for auth module";
          type = lib.types.submodule {
            freeformType = jsonFormat.type;
            options = {
              allowSignup = lib.mkOption {
                type = lib.types.bool;
                description = "Allow users to sign up";
                default = false;
              };
            };
          };
        };

        storages = lib.mkOption {
          description = "Configuration for storages module";

          type = lib.types.submodule {
            freeformType = jsonFormat.type;
            options = {
              avatar = lib.mkOption {
                description = "Configuration for user avatars storage";
                type = lib.types.submodule {
                  freeformType = jsonFormat.type;
                  options = {
                    storage = lib.mkOption {
                      type = lib.types.submodule {
                        freeformType = jsonFormat.type;
                        options = {
                          provider = lib.mkOption {
                            type = lib.types.str;
                            description = "Storage provider";
                            default = "fs";
                          };

                          bucket = lib.mkOption {
                            type = lib.types.str;
                            description = "Storage bucket";
                            default = "avatars";
                          };

                          config = lib.mkOption {
                            type = lib.types.submodule {
                              freeformType = jsonFormat.type;
                              options = {
                                path = lib.mkOption {
                                  type = lib.types.nullOr lib.types.str;
                                  description = "Path to the storage";
                                  default =
                                    if (cfg.settings.storages.avatar.storage.provider == "fs") then "${cfg.dataDir}/storage" else null;
                                };
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                };
              };

              blob = lib.mkOption {
                description = "Configuration for blob storage";
                type = lib.types.submodule {
                  freeformType = jsonFormat.type;
                  options = {
                    storage = lib.mkOption {
                      type = lib.types.submodule {
                        freeformType = jsonFormat.type;
                        options = {
                          provider = lib.mkOption {
                            type = lib.types.str;
                            description = "Storage provider";
                            default = "fs";
                          };
                          bucket = lib.mkOption {
                            type = lib.types.str;
                            description = "Storage bucket";
                            default = "blobs";
                          };
                          config = lib.mkOption {
                            type = lib.types.submodule {
                              freeformType = jsonFormat.type;
                              options = {
                                path = lib.mkOption {
                                  type = lib.types.nullOr lib.types.str;
                                  description = "Path to the storage";
                                  default =
                                    if (cfg.settings.storages.blob.storage.provider == "fs") then "${cfg.dataDir}/storage" else null;
                                };
                              };
                            };
                          };
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
        server = lib.mkOption {
          description = "Configuration for server module";
          type = lib.types.submodule {
            freeformType = jsonFormat.type;
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Name of the server";
                default = "Nix Affine Server";
              };
              externalUrl = lib.mkOption {
                type = lib.types.str;
                description = "External URL of the server";
                default = "${if cfg.settings.server.https then "https" else "http"}://${
                  if cfg.nginx.enable then cfg.settings.server.host else "127.0.0.1"
                }${if !cfg.nginx.enable then ":${toString cfg.settings.server.port}" else ""}";
                example = "https://affine.example.com";
              };
              https = lib.mkOption {
                type = lib.types.bool;
                description = "Whether the server is served over HTTPS";
                default = true;
              };
              host = lib.mkOption {
                type = lib.types.str;
                description = "Host of the server";
                example = "affine.example.com";
              };
              port = lib.mkOption {
                type = lib.types.port;
                description = "Port of the server";
                default = 3210;
              };
              listenAddr = lib.mkOption {
                type = lib.types.str;
                description = "Listen address of the server";
                default = "127.0.0.1";
              };
            };
          };
        };

        flags = lib.mkOption {
          description = "Configuration for flags module";
          type = lib.types.submodule {
            freeformType = jsonFormat.type;
            options = {
              allowGuestDemoWorkspace = lib.mkOption {
                type = lib.types.bool;
                description = "Allow guest demo workspace";
                default = false;
              };
            };
          };
        };

        client = lib.mkOption {
          description = "Configuration for client module";
          type = lib.types.submodule {
            freeformType = jsonFormat.type;
            options = {
              versionControl = lib.mkOption {
                description = "Configuration for version control module";
                type = lib.types.submodule {
                  freeformType = jsonFormat.type;
                  options = {
                    enabled = lib.mkEnableOption "Enable version control";
                  };
                };
              };
            };
          };
        };

        payment = lib.mkOption {
          description = "Configuration for payment module";
          type = lib.types.submodule {
            freeformType = jsonFormat.type;
            options = {
              showLifetimePrice = lib.mkOption {
                type = lib.types.bool;
                description = "Show lifetime price";
                default = false;
              };
            };
          };
        };
      };
    };
  };
}
