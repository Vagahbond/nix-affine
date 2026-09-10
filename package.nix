# https://nixos.org/manual/nixpkgs/stable/#javascript-yarn
{
  affine,
  cacert,
  cargo,
  cmake,
  fetchFromGitHub,
  lib,
  nodejs_24,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
  yarn-berry_4,
  prisma-engines_6,
  # inputs,
  rustc,
  opus,
}:
let
  nodejs = nodejs_24;

  # Upstream AFFiNE pins `.yarnrc.yml` to yarn 4.18.0 (see .yarn/releases/yarn-4.18.0.cjs),
  # while nixpkgs' yarn-berry_4 defaults to 4.14.1. That version gap breaks the builtin
  # `compat/typescript` patch for the `@typescript/typescript6` alias (missing lib/_tsc.js).
  # Rebuild yarn-berry from the matching upstream tag so patch/fetch behavior matches.
  mYarn = yarn-berry_4.overrideAttrs (_: {
    version = "4.18.0";
    src = fetchFromGitHub {
      owner = "yarnpkg";
      repo = "berry";
      tag = "@yarnpkg/cli/4.18.0";
      hash = "sha256-pO89wh17cW9/RGKjo70yiefr+9nlJAQs4ZEdUnzdgQM=";
    };
  });

in
stdenv.mkDerivation (finalAttrs: {
  pname = "affine-server";
  version = "0.27.4";
  BUILD_TYPE = "production";

  dontUseCmakeConfigure = true;

  NODE_EXTRA_CA_CERTS = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  src = affine;

  missingHashes = ./missing-hashes.json;

  offlineCache = mYarn.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-wEx7l28G6uC6ZwU6NCrsJCsekaXi5Gm/rEXAajQ5gSk=";
  };

  # https://github.com/NixOS/nixpkgs/issues/254369#issuecomment-2080460150
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    hash = "sha256-z3PWCHMvof87vi8AJJ73DjvlSJCDvMxUGD52v1eRl2M=";
  };

  nativeBuildInputs = [
    cargo
    cmake
    rustc
    mYarn
    mYarn.yarnBerryConfigHook
    openssl
    nodejs
    pkg-config
    rustPlatform.cargoSetupHook
  ];

  buildInputs = [
    opus
  ];

  # TODO: run the version script
  # https://github.com/toeverything/AFFiNE/blob/canary/.github/actions/setup-version/action.yml
  configurePhase = ''
    runHook preConfigure

    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    export PRISMA_QUERY_ENGINE_BINARY=${prisma-engines_6}/bin/query-engine
    export PRISMA_QUERY_ENGINE_LIBRARY=${prisma-engines_6}/lib/libquery_engine.node
    export PRISMA_SCHEMA_ENGINE_BINARY=${prisma-engines_6}/bin/schema-engine
    export npm_config_nodedir=${nodejs}



    runHook postConfigure
  '';
  /*
        mkdir -p "$TMPDIR/yarn-cache"
        ln -s $yarnOfflineCache/yarn-offline-cache $TMPDIR/yarn-cache
        export YARN_CACHE_FOLDER="$TMPDIR/yarn-cache"

        yarn install --immutable --mode=skip-build

      '';
  */

  buildPhase = ''
    runHook preBuild


     yarn affine @affine/server-native build

     # cp packages/backend/native/server-native.node packages/backend/native/server-native.arm64.node
     # cp packages/backend/native/server-native.node packages/backend/native/server-native.armv7.node
     # cp packages/backend/native/server-native.node packages/backend/native/server-native.x64.node

     yarn affine @affine/server build
     yarn affine @affine/web build
     yarn affine @affine/admin build


     yarn workspace @affine/server build

     yarn workspace @affine/server prisma generate

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    cp -r ./packages/frontend/apps/web/dist $out/web
    cp -r ./packages/frontend/admin/dist $out/admin
    cp -r ./packages/backend/server/dist $out/server


    echo "Installing"
    ls

    cp -r ./* $out/

    runHook postInstall
  '';

  meta = {
    description = "A privacy-focused, local-first, open-source, and ready-to-use alternative for Notion & Miro.";
    homepage = "https://affine.pro";
    license = lib.licenses.mit;
  };
})
