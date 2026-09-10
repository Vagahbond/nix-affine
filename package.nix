# https://nixos.org/manual/nixpkgs/stable/#javascript-yarn
{
  affine,
  cacert,
  cargo,
  cmake,
  lib,
  nodejs_24,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
  mYarn,
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

  arch =
    if stdenv.hostPlatform.system == "x86_64-linux" then
      {
        short = "x64";
        triple = "x86_64-unknown-linux-gnu";
      }
    else if stdenv.hostPlatform.system == "aarch64-linux" then
      {
        short = "arm64";
        triple = "aarch64-unknown-linux-gnu";
      }
    else if stdenv.hostPlatform.system == "x86_64-darwin" then
      {
        short = "x64";
        triple = "x86_64-apple-darwin";
      }
    else if stdenv.hostPlatform.system == "aarch64-darwin" then
      {
        short = "arm64";
        triple = "aarch64-apple-darwin";
      }
    else
      throw "Unsupported system: ${stdenv.hostPlatform.system}";

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
    hash = "sha256-lQI/QjeDAIKGnUJw/8KAIxv273wkhzjVRzTYEQWtR8s=";
  };

  # https://github.com/NixOS/nixpkgs/issues/254369#issuecomment-2080460150
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    hash = "sha256-vD4Tq5bWmyArYv67+znJPB0E9Gu7vKTFtKpaB4w72s4=";
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

  /**
    server-native.node import is failing on my mac, likely because of some Rosetta confusion: built for x64 but ARM NodeJS runtime, or something like that. Too annoying to fix, especially when no one is ever going to run this on a M mac right ? RIGHT ?
  */
  buildPhase = ''
    runHook preBuild


     yarn affine @affine/server-native build 

     # cp packages/backend/native/server-native.node packages/backend/native/server-native.${arch.short}.node

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
