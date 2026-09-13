# https://nixos.org/manual/nixpkgs/stable/#javascript-yarn
{
  affine,
  cacert,
  cargo,
  cmake,
  lib,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
  mYarn,
  rustc,
  opus,
  nodejs_24
  self
}:
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
    export npm_config_nodedir=${nodejs_24}

    cp ${self.packages.server-native}/server-native.node ./packages/backend/native/server-native.node

    runHook postConfigure
  '';

  /**
    server-native.node import is failing on my mac, likely because of some Rosetta confusion: built for x64 but ARM NodeJS runtime, or something like that. Too annoying to fix, especially when no one is ever going to run this on a M mac right ? RIGHT ?
  */
  buildPhase = ''
    runHook preBuild

     yarn affine @affine/server build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out

    cp -r ./packages/backend/server/dist $out/server

    runHook postInstall
  '';

  meta = {
    description = "A privacy-focused, local-first, open-source, and ready-to-use alternative for Notion & Miro.";
    homepage = "https://affine.pro";
    license = lib.licenses.mit;
  };
})
