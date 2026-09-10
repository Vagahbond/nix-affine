{ pkgs, ... }:
let
  update-missing-hashes = pkgs.writeShellScriptBin "update-missing-hashes" ''
    ${pkgs.yarn-berry_4.yarn-berry-fetcher}/bin/yarn-berry-fetcher missing-hashes ${../yarn.lock} > ./nix/missing-hashes.json
  '';
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    nodejs_24
    # Note: Might need to override yarn-berry_4 version
    yarn-berry_4
    rustc
    cargo
    cmake
    nodejs
    update-missing-hashes
  ];

  env = {
  };

  shellHook = ''
    echo "Developping Affine";
  '';
}
