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
stdenv.mkDerivation (
  finalAttrs:
  let

    nodeModulesCache = mYarn.fetchYarnBerryDeps {
      inherit (finalAttrs) src missingHashes;
      hash = "sha256-lQI/QjeDAIKGnUJw/8KAIxv273wkhzjVRzTYEQWtR8s=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit (finalAttrs) src;
      hash = "sha256-vD4Tq5bWmyArYv67+znJPB0E9Gu7vKTFtKpaB4w72s4=";
    };
  in
  {
    pname = "affine-server";
    version = "0.27.4";
    BUILD_TYPE = "production";

    dontUseCmakeConfigure = true;

    NODE_EXTRA_CA_CERTS = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    src = affine;

    missingHashes = ./missing-hashes.json;

    offlineCache = nodeModulesCache;

    # https://github.com/NixOS/nixpkgs/issues/254369#issuecomment-2080460150
    inherit cargoDeps;
    nativeBuildInputs = [
      cargo
      cmake
      rustc
      mYarn
      mYarn.yarnBerryConfigHook
      openssl
      nodejs_24
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
      export npm_config_nodedir=${nodejs_24}



      runHook postConfigure
    '';

    /**
      server-native.node import is failing on my mac, likely because of some Rosetta confusion: built for x64 but ARM NodeJS runtime, or something like that. Too annoying to fix, especially when no one is ever going to run this on a M mac right ? RIGHT ?
    */
    buildPhase = ''
      runHook preBuild

      yarn affine @affine/web build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out

      cp -r ./packages/frontend/apps/web/dist $out/web

      runHook postInstall
    '';

    meta = {
      description = "A privacy-focused, local-first, open-source, and ready-to-use alternative for Notion & Miro.";
      homepage = "https://affine.pro";
      license = lib.licenses.mit;
    };
  }
)
