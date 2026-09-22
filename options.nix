# Schema available here : https://github.com/toeverything/affine/releases/latest/download/config.schema.json
{
  lib,
  pkgs,
  config,
}:
with lib;
let
  secret = types.submodule {
    options = {
      _secret = mkOption {
        type = types.path;
        description = "Path to the secret file";
      };
    };
  };

  jsonFormat = pkgs.formats.json { };

  cfg = config.services.affine-server;
in
{
  enable = mkEnableOption "AFFiNE self-hosted server";

  package = mkOption {
    type = types.package;
    default = pkgs.affine-server;
    description = "The affine-server package to run.";
  };

  nginx = mkOption {
    description = "Configuration for nginx";
    type = types.submodule {
      options = {
        enable = mkEnableOption "an nginx virtual host for affine-server";

        enableACME = mkOption {
          type = types.bool;
          default = cfg.nginx.enable;
          description = "Whether to request an ACME certificate for the virtual host.";
        };
      };
    };
  };

  redis = {
    createLocally = mkEnableOption "a local Redis instance via NixOS' redis module";
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

  database = {
    createLocally = mkEnableOption "a local PostgreSQL instance via NixOS' postgresql module";

    name = mkOption {
      type = types.str;
      default = "affine";
      description = "Database name.";
    };

    user = mkOption {
      type = types.str;
      default = cfg.database.name;
      description = "Database user.";
    };

    password = mkOption {
      type = types.nullOr types.str;
      default = "affine";
      description = "Database password.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Database host.";
    };

    port = mkOption {
      type = types.port;
      default = 5432;
      description = "Database port.";
    };
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

  environmentFile = mkOption {
    type = types.nullOr types.path;
    default = null;
    description = "Path to the environment file (refer to https://docs.affine.pro/self-host-affine/references/environment-variables)";
  };

  settings = mkOption {
    description = ''
      AFFiNE server settings.
          You can specify secret values in this configuration by setting somevalue._secret = "/path/to/file" instead of setting somevalue directly.
          Refer to https://github.com/toeverything/affine/releases/latest/download/config.schema.json
    '';

    type = types.submodule {
      freeformType = jsonFormat.type;
      options = {
        metrics = mkOption {
          type = types.submodule {
            freeformType = jsonFormat.type;
            options = {
              enabled = mkOption {
                type = types.bool;
                description = "Enable metric and tracing collection";
                default = false;
              };
            };
          };
        };

        crypto = mkOption {
          type = types.submodule {
            freeformType = jsonFormat.type;
            options = {
              privateKey = mkOption {
                type = types.either secret (types.nullOr types.str);
                description = "The private key for used by the crypto module to create signed tokens or encrypt data.\n@default \"\"\n@environment `AFFINE_PRIVATE_KEY`";
                example = {
                  _secret = "/var/lib/affine/private.key";
                };
              };
            };
          };
        };

        auth = mkOption {
          description = "Configuration for auth module";
          type = types.submodule {
            freeformType = jsonFormat.type;
            options = {
              allowSignup = mkOption {
                type = types.bool;
                description = "Allow users to sign up";
                default = false;
              };
            };
          };
        };

        storages = mkOption {
          description = "Configuration for storages module";

          type = types.submodule {
            freeformType = jsonFormat.type;
            options = {
              avatar = mkOption {
                description = "Configuration for user avatars storage";
                type = types.submodule {
                  freeformType = jsonFormat.type;
                  options = {
                    storage = mkOption {
                      type = types.submodule {
                        freeformType = jsonFormat.type;
                        options = {
                          provider = mkOption {
                            type = types.str;
                            description = "Storage provider";
                            default = "fs";
                          };

                          bucket = mkOption {
                            type = types.str;
                            description = "Storage bucket";
                            default = "avatars";
                          };

                          config = mkOption {
                            type = types.submodule {
                              freeformType = jsonFormat.type;
                              options = {
                                path = mkOption {
                                  type = types.str;
                                  description = "Path to the storage";
                                  default = "${cfg.dataDir}/storage";
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

              blob = mkOption {
                description = "Configuration for blob storage";
                type = types.submodule {
                  freeformType = jsonFormat.type;
                  options = {
                    storage = mkOption {
                      type = types.submodule {
                        freeformType = jsonFormat.type;
                        options = {
                          provider = mkOption {
                            type = types.str;
                            description = "Storage provider";
                            default = "fs";
                          };
                          bucket = mkOption {
                            type = types.str;
                            description = "Storage bucket";
                            default = "blobs";
                          };
                          config = mkOption {
                            type = types.submodule {
                              freeformType = jsonFormat.type;
                              options = {
                                path = mkOption {
                                  type = types.str;
                                  description = "Path to the storage";
                                  default = "${cfg.dataDir}/storage";
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
        server = mkOption {
          description = "Configuration for server module";
          type = types.submodule {
            freeformType = jsonFormat.type;
            options = {
              name = mkOption {
                type = types.str;
                description = "Name of the server";
                default = "Nix Affine Server";
              };
              externalUrl = mkOption {
                type = types.str;
                description = "External URL of the server";
                default = "${if cfg.settings.server.https then "https" else "http"}://${
                  if cfg.nginx.enable then cfg.settings.server.host else "127.0.0.1"
                }${if !cfg.nginx.enable then ":${toString cfg.settings.server.port}" else ""}";
                example = "https://affine.example.com";
              };
              https = mkOption {
                type = types.bool;
                description = "Whether the server is served over HTTPS";
                default = true;
              };
              host = mkOption {
                type = types.str;
                description = "Host of the server";
                example = "affine.example.com";
              };
              port = mkOption {
                type = types.port;
                description = "Port of the server";
                default = 3210;
              };
              listenAddr = mkOption {
                type = types.str;
                description = "Listen address of the server";
                default = "127.0.0.1";
              };
            };
          };
        };

        flags = mkOption {
          description = "Configuration for flags module";
          type = types.submodule {
            freeformType = jsonFormat.type;
            options = {
              allowGuestDemoWorkspace = mkOption {
                type = types.bool;
                description = "Allow guest demo workspace";
                default = false;
              };
            };
          };
        };

        client = mkOption {
          description = "Configuration for client module";
          type = types.submodule {
            freeformType = jsonFormat.type;
            options = {
              versionControl = mkOption {
                description = "Configuration for version control module";
                type = types.submodule {
                  freeformType = jsonFormat.type;
                  options = {
                    enabled = mkEnableOption "Enable version control";
                  };
                };
              };
            };
          };
        };

        payment = mkOption {
          description = "Configuration for payment module";
          type = types.submodule {
            freeformType = jsonFormat.type;
            options = {
              showLifetimePrice = mkOption {
                type = types.bool;
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
