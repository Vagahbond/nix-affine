# https://nixos.org/manual/nixpkgs/stable/#javascript-yarn
{
  affine,
  cacert,
  cargo,
  cmake,
  fetchFromGitHub,
  lib,
  makeBinaryWrapper,
  nodejs_24,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
  mYarn,
  yarn,
  prisma-engines_6,
  # inputs,
  rustc,
  opus,
}:
let
  nodejs = nodejs_24;

  prismaEngines = prisma-engines_6.overrideAttrs (
    finalAttrs: previousAttrs: {
      version = "6.8.2";
      src = fetchFromGitHub {
        owner = "prisma";
        repo = "prisma-engines";
        tag = finalAttrs.version;
        hash = "sha256-YvP3yJQoe+q7jjpwntaYkYjxyoDzqnXcpIZa4Y+I/+E=";
      };
      cargoDeps = rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) pname version src;
        patches = previousAttrs.cargoPatches or [ ];
        hash = "sha256-5iJM0mqBfY3KdtToxCas4Xxu5jCf+CNwAUA2zuGu+iM=";
      };
    }
  );
in
stdenv.mkDerivation (
  finalAttrs:
  let
    nodeModulesCache = mYarn.fetchYarnBerryDeps {
      inherit (finalAttrs) src missingHashes;
      hash = "sha256-qOsLgyEluCX0ivMGSfIf8OZf/oA/LiFvmNe80JG7FW8=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit (finalAttrs) src;
      hash = "sha256-fQY4DmkbZQljXQzWRNLzaYxdPoenWTbOtjBvqT/HFYE=";
    };

    targetArch =
      if stdenv.hostPlatform.isx86_64 then
        "amd64"
      else if stdenv.hostPlatform.isAarch64 then
        "arm64"
      else if stdenv.hostPlatform.isArm then
        "armv7"
      else
        throw "Unsupported architecture";

  in
  {
    pname = "affine-server";
    version = "0.27.4";
    BUILD_TYPE = "stable";

    dontUseCmakeConfigure = true;

    NODE_EXTRA_CA_CERTS = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    GITHUB_SHA = affine.rev;

    src = affine;

    patches = [
      ./patches/generate-graphql-schema-in-memory.patch
    ];

    missingHashes = ./missing-hashes.json;

    offlineCache = nodeModulesCache;

    # https://github.com/NixOS/nixpkgs/issues/254369#issuecomment-2080460150
    inherit cargoDeps;

    nativeBuildInputs = [
      cargo
      cmake
      rustc
      mYarn.yarnBerryConfigHook
      makeBinaryWrapper
      openssl
      nodejs
      pkg-config
      rustPlatform.cargoSetupHook
    ];

    buildInputs = [
      opus
      mYarn
    ];

    # TODO: run the version script
    # https://github.com/toeverything/AFFiNE/blob/canary/.github/actions/setup-version/action.yml
    configurePhase = ''
      runHook preConfigure

      export ELECTRON_SKIP_BINARY_DOWNLOAD=1
      export PRISMA_QUERY_ENGINE_BINARY=${prismaEngines}/bin/query-engine
      export PRISMA_QUERY_ENGINE_LIBRARY=${prismaEngines}/lib/libquery_engine.node
      export PRISMA_SCHEMA_ENGINE_BINARY=${prismaEngines}/bin/schema-engine

      runHook postConfigure
    '';

    /**
      server-native.node import is failing on my mac, likely because of some Rosetta confusion: built for x64 but ARM NodeJS runtime, or something like that. Too annoying to fix, especially when no one is ever going to run this on a M mac right ? RIGHT ?
    */
    buildPhase = ''
      runHook preBuild


      yarn affine @affine/server-native build

      # TODO: avoid this copy (won't build server without it...)
      cp ./packages/backend/native/server-native.node ./packages/backend/native/server-native.arm64.node
      cp ./packages/backend/native/server-native.node ./packages/backend/native/server-native.armv7.node
      cp ./packages/backend/native/server-native.node ./packages/backend/native/server-native.x64.node


       yarn workspace @affine/server build

       yarn affine @affine/web build
       yarn affine @affine/admin build
       yarn affine @affine/mobile build

      yarn workspaces focus @affine/server --production
      yarn workspace @affine/server prisma generate

      AFFINE_DOCKER_CLEAN=1 TARGETARCH="${targetArch}" node ./packages/backend/server/scripts/docker-clean.mjs 

      rm -rf ./node_modules/@affine


      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -r ./packages/backend/server $out
      cp -r ./node_modules $out/

      cp -r ./packages/frontend/apps/web/dist $out/static
      cp -r ./packages/frontend/admin/dist $out/static/admin
      cp -r ./packages/frontend/apps/mobile/dist $out/static/mobile

      rm -rf $out/node_modules/@affine

      mkdir -p $out/bin

      makeBinaryWrapper ${nodejs}/bin/node $out/bin/affine-server-predeploy \
        --chdir "$out" \
        --add-flags "./scripts/self-host-predeploy.js" \
        --set-default NODE_ENV production \
        --set-default PRISMA_QUERY_ENGINE_BINARY ${prismaEngines}/bin/query-engine \
        --set-default PRISMA_QUERY_ENGINE_LIBRARY ${prismaEngines}/lib/libquery_engine.node \
        --set-default PRISMA_SCHEMA_ENGINE_BINARY ${prismaEngines}/bin/schema-engine \
        --set-default DEPLOYMENT_TYPE selfhosted \
        --prefix PATH : "${
          lib.makeBinPath [
            (yarn.override { inherit nodejs; })
            nodejs
          ]
        }" \
        ${lib.optionalString stdenv.isLinux "--suffix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            openssl
            opus
          ]
        }"}

      makeBinaryWrapper ${nodejs}/bin/node $out/bin/affine-server \
        --chdir "$out" \
        --add-flags "dist/main.js" \
        --set-default NODE_ENV production \
        --set-default PRISMA_QUERY_ENGINE_BINARY ${prismaEngines}/bin/query-engine \
        --set-default PRISMA_QUERY_ENGINE_LIBRARY ${prismaEngines}/lib/libquery_engine.node \
        --set-default PRISMA_SCHEMA_ENGINE_BINARY ${prismaEngines}/bin/schema-engine \
        --set-default DEPLOYMENT_TYPE selfhosted \
        ${lib.optionalString stdenv.isLinux "--suffix LD_LIBRARY_PATH : ${
          lib.makeLibraryPath [
            openssl
            opus
          ]
        }"}



      runHook postInstall
    '';

    meta = {
      description = "A privacy-focused, local-first, open-source, and ready-to-use alternative for Notion & Miro.";
      homepage = "https://affine.pro";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [ vagahbond ];
    };
  }
)
