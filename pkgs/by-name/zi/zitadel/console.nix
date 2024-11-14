{
  generateProtobufCode,
  version,
  zitadelRepo,
}: {
  lib,
  stdenv,
  fetchYarnDeps,
  yarnConfigHook,
  yarnBuildHook,
  nodejs,
  grpc-gateway,
  protoc-gen-grpc-web,
  protoc-gen-js,
}: let
  protobufGenerated = generateProtobufCode {
    pname = "zitadel-console";
    nativeBuildInputs = [
      grpc-gateway
      protoc-gen-grpc-web
      protoc-gen-js
    ];
    workDir = "console";
    bufArgs = "../proto --include-imports --include-wkt";
    outputPath = "src/app/proto";
    hash = "sha256-hdtt+d23OF2Cb/plhbbqSBJF0yVe6hOZNdGg7fh87G0=";
    # hash = "sha256-BBXFt4f2SQphr106sQ0eEL4Z2ooAI8fxXhu2rKqhjb4=";
  };
in
  stdenv.mkDerivation {
    pname = "zitadel-console";
    inherit version;

    src = zitadelRepo;

    sourceRoot = "${zitadelRepo.name}/console";

    offlineCache = fetchYarnDeps {
      yarnLock = "${zitadelRepo}/console/yarn.lock";
      hash = "sha256-Ik43we7syU1t0dfZHGiRF2At/SXtt1ZKW5Nf/BJ7cLM=";
    };

    nativeBuildInputs = [
      yarnConfigHook
      yarnBuildHook
      nodejs
    ];

    preBuild = ''
      cp -r ${protobufGenerated} src/app/proto
    '';

    installPhase = ''
      runHook preInstall
      cp -r dist/console "$out"
      runHook postInstall
    '';
  }
