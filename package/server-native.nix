# https://nixos.org/manual/nixpkgs/stable/#javascript-yarn
{
  affine,
  cargo,
  cmake,
  lib,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
  rustc,
  opus,
  mYarn,
  prisma-engines_6,
  nodejs_24,
  tree,
}:
stdenv.mkDerivation (finalAttrs:

{
  pname = "affine-server-native";
  version = "0.27.4";
  BUILD_TYPE = "production";

  dontUseCmakeConfigure = true;

  src = affine;

  # https://github.com/NixOS/nixpkgs/issues/254369#issuecomment-2080460150
  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) src;
    hash = "sha256-vD4Tq5bWmyArYv67+znJPB0E9Gu7vKTFtKpaB4w72s4=";
  };

  nativeBuildInputs = [
    cargo
    cmake
    rustc
    openssl
    pkg-config
    rustPlatform.cargoSetupHook
    mYarn
    mYarn.yarnBerryConfigHook
  ];

  buildInputs = [
    opus
  ];
  offlineCache = mYarn.fetchYarnBerryDeps {
    inherit (finalAttrs) src missingHashes;
    hash = "sha256-lQI/QjeDAIKGnUJw/8KAIxv273wkhzjVRzTYEQWtR8s=";
  };

  missingHashes = ../missing-hashes.json;

  configurePhase = ''
    runHook preConfigure

    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    export PRISMA_QUERY_ENGINE_BINARY=${prisma-engines_6}/bin/query-engine
    export PRISMA_QUERY_ENGINE_LIBRARY=${prisma-engines_6}/lib/libquery_engine.node
    export PRISMA_SCHEMA_ENGINE_BINARY=${prisma-engines_6}/bin/schema-engine
    export npm_config_nodedir=${nodejs_24}



    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    yarn affine @affine/server-native build 
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    ${tree}/bin/tree ./package/backend/native



    cp ./packages/backend/native/server-native.node $out/server-native.node

    runHook postInstall
  '';

  meta = {
    description = "A privacy-focused, local-first, open-source, and ready-to-use alternative for Notion & Miro.";
    homepage = "https://affine.pro";
    license = lib.licenses.mit;
  };
})
