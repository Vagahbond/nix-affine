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
```

Look into `options.nix` for more options.

# Building package 

Beware, as Affine is going to be built from source on your machine. 

It takes at least 15 gigs of ram and a decent CPU. 

Solutions to that include: 
* [NixBuild](https://eu.nixbuild.net/)
* Including this package in nixpkgs

I intend to PR this package and module to nixpkgs but I need to try it out for a while first. 

Do not hesitate to open an issue or a PR.

