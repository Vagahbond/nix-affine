{
  description = "Nix module to self-host Affine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    affine = {
      url = "github:toeverything/affine/canary";
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
    in
    {
      formatter = forAllSupportedSystems [ "aarch64-darwin" "x86_64-linux" ] (pkgs: pkgs.nixpkgs-fmt);

      packages = forAllSupportedSystems [ "x86_64-linux" "aarch64-darwin" ] (pkgs: rec {
        affine-server = pkgs.callPackage ./package.nix { inherit affine; };

        default = affine-server;
      });

      nixosModules.default = _: {
        nixpkgs.overlays = [ self.overlays.default ];
        imports = [ ./module.nix ];
      };
      devShells = forAllSupportedSystems [ "x86_64-linux" "aarch64-darwin" ] (pkgs: {
        default = import ./shell.nix { inherit self pkgs; };
      });

    };
}
