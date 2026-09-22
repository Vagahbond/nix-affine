{
  description = "Nix module to self-host Affine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    affine = {
      url = "github:toeverything/affine/v0.27.4";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    affine,
    ...
  }: let
    forAllSupportedSystems = systems: function:
      nixpkgs.lib.genAttrs systems (
        system:
          function (
            import nixpkgs {
              inherit system;
            }
          )
      );

    mkYarn = pkgs:
      pkgs.yarn-berry_4.overrideAttrs (_: {
        version = "4.18.0";
        src = pkgs.fetchFromGitHub {
          owner = "yarnpkg";
          repo = "berry";
          tag = "@yarnpkg/cli/4.18.0";
          hash = "sha256-pO89wh17cW9/RGKjo70yiefr+9nlJAQs4ZEdUnzdgQM=";
        };
      });
  in {
    formatter = forAllSupportedSystems ["aarch64-darwin" "x86_64-linux"] (pkgs: pkgs.nixpkgs-fmt);

    packages = forAllSupportedSystems ["x86_64-linux" "aarch64-darwin"] (
      pkgs: let
        mYarn = mkYarn pkgs;
        nodejs = pkgs.nodejs_24;
        missingHashes = ./missing-hashes.json;

        offlineCache = mYarn.fetchYarnBerryDeps {
          src = ./.;
          inherit missingHashes;
          hash = "sha256-qOsLgyEluCX0ivMGSfIf8OZf/oA/LiFvmNe80JG7FW8=";
        };

        cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
          src = ./.;
          hash = "sha256-fQY4DmkbZQljXQzWRNLzaYxdPoenWTbOtjBvqT/HFYE=";
        };
      in rec {
        server-native = pkgs.callPackage ./packages/server-native.nix {
          inherit
            affine
            cargoDeps
            offlineCache
            mYarn
            nodejs
            missingHashes
            ;
        };

        affine-server = pkgs.callPackage ./package.nix {
          inherit affine mYarn;
        };

        default = affine-server;
      }
    );

    nixosModules.default = _: {
      nixpkgs.overlays = [self.overlays.default];
      imports = [./module.nix];
    };

    devShells = forAllSupportedSystems ["x86_64-linux" "aarch64-darwin"] (pkgs: {
      default = import ./shell.nix {
        inherit self pkgs affine;
        yarn = mkYarn pkgs;
      };
    });
  };
}
