{
  generateProtobufCode,
  version,
  zitadelRepo,
}: {
  mkYarnPackage,
  fetchYarnDeps,
  lib,
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
  mkYarnPackage rec {
    name = "zitadel-console";
    inherit version;

    src = zitadelRepo + "/console";
    packageJSON = "${src}/package.json";
    offlineCache = fetchYarnDeps {
      name = "zitadel-yarn-cache";
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-Ik43we7syU1t0dfZHGiRF2At/SXtt1ZKW5Nf/BJ7cLM=";
      #  hash = "sha256-MWATjfhIbo3cqpzOdXP52f/0Td60n99OTU1Qk6oWmXU=";
    };

    postPatch = ''
      substituteInPlace src/styles.scss \
        --replace "/node_modules/flag-icons" "flag-icons"

      substituteInPlace angular.json \
        --replace "./node_modules/tinycolor2" "../../node_modules/tinycolor2"
    '';

    buildPhase = ''
      mkdir deps/console/src/app/proto
      mkdir deps/docs
      cp -r ${zitadelRepo}/docs/frameworks.json deps/docs
      cp -r ${protobufGenerated}/* deps/console/src/app/proto/
      yarn --offline build
    '';

    installPhase = ''
      cp -r deps/console/dist/console $out
    '';

    doDist = false;
  }
