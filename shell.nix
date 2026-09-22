{
  pkgs,
  affine,
  yarn,
  ...
}: let
  update-missing-hashes = pkgs.writeShellScriptBin "update-missing-hashes" ''
    ${yarn.yarn-berry-fetcher}/bin/yarn-berry-fetcher missing-hashes ${affine}/yarn.lock > ./missing-hashes.json
  '';
in
  pkgs.mkShell {
    buildInputs = with pkgs; [
      nodejs_24
      rustc
      cargo
      cmake
      nodejs
      update-missing-hashes
      yarn
    ];

    env = {
    };

    shellHook = ''
      echo "Developping Affine";
    '';
  }
