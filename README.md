# Nix Affine

Nix module to self-host Affine.

## Installation

```nix 
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    affine = {
      url = "git://git.vagahbond.com/vagahbond/nix-affine.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      affine,
      ...
    }: {
        nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            {
              services.affine-server = {
                enable = true;
                package = affine.packages.default;
                settings.server.host = "affine.example.com";
                settings.server.port = 3210;
                settings.server.https = true;
              };
            }
          ];
        };
    }

Look into `options.nix` for more options.


