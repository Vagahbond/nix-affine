# https://nixos.org/manual/nixpkgs/stable/#javascript-yarn
{
  affine,
  cacert,
  cargo,
  cmake,
  lib,
  makeWrapper,
  nodejs,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
  mYarn,
  prisma-engines_6,
  # inputs,
  rustc,
  opus,
  offlineCache,
  cargoDeps,
  missingHashes,
}:
stdenv.mkDerivation (_: {
  pname = "affine-server-native";
  version = "0.27.4";

  inherit missingHashes offlineCache cargoDeps;

  BUILD_TYPE = "stable";

  dontUseCmakeConfigure = true;

  NODE_EXTRA_CA_CERTS = "${cacert}/etc/ssl/certs/ca-bundle.crt";
  SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

  GITHUB_SHA = affine.rev;

  src = affine;

  nativeBuildInputs = [
    cargo
    cmake
    rustc
    mYarn
    mYarn.yarnBerryConfigHook
    makeWrapper
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

    runHook postConfigure
  '';

  /**
    server-native.node import is failing on my mac, likely because of some Rosetta confusion: built for x64 but ARM NodeJS runtime, or something like that. Too annoying to fix, especially when no one is ever going to run this on a M mac right ? RIGHT ?
  */
  buildPhase = ''
    runHook preBuild
    yarn workspaces focus @affine/server-native;
    yarn affine @affine/server-native build;
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin 

    cp ./packages/backend/native/server-native.node $out/bin/server-native.node

    runHook postInstall
  '';

  meta = {
    description = "A privacy-focused, local-first, open-source, and ready-to-use alternative for Notion & Miro.";
    homepage = "https://affine.pro";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ vagahbond ];
  };
})
