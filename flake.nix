{
  description = "Nix module to self-host Affine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    affine = {
      url = "github:toeverything/affine/v0.27.4";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      affine,
      ...
    }:
    let
      forAllSupportedSystems =
        systems: function:
        nixpkgs.lib.genAttrs systems (
          system:
          function (
            import nixpkgs {
              inherit system;
            }
          )
        );

      mYarn =
        pkgs:
        pkgs.yarn-berry_4.overrideAttrs (_: {
          version = "4.18.0";
          src = pkgs.fetchFromGitHub {
            owner = "yarnpkg";
            repo = "berry";
            tag = "@yarnpkg/cli/4.18.0";
            hash = "sha256-pO89wh17cW9/RGKjo70yiefr+9nlJAQs4ZEdUnzdgQM=";
          };
        });

    in
    {
      formatter = forAllSupportedSystems [ "aarch64-darwin" "x86_64-linux" ] (pkgs: pkgs.nixpkgs-fmt);

      packages = forAllSupportedSystems [ "x86_64-linux" "aarch64-darwin" ] (pkgs: rec {

        affine-server = pkgs.callPackage ./package.nix {
          inherit affine;
          mYarn = mYarn pkgs;
        };

        default = affine-server;
      });

      nixosModules.default = _: {
        nixpkgs.overlays = [ self.overlays.default ];
        imports = [ ./module.nix ];
      };
      devShells = forAllSupportedSystems [ "x86_64-linux" "aarch64-darwin" ] (pkgs: {
        default = import ./shell.nix {
          inherit self pkgs affine;
          yarn = mYarn pkgs;
        };
      });

    };
}
