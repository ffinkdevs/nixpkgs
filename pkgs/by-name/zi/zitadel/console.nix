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
    hash = "sha256-PulKzsfFTJkqsJCgOZ7+LHJYdRNqAg6ru+cx8OzMhTM=";
  };
in
  mkYarnPackage rec {
    name = "zitadel-console";
    inherit version;

    src = "${zitadelRepo}/console";

    packageJSON = "${src}/package.json";
    offlineCache = fetchYarnDeps {
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-MWATjfhIbo3cqpzOdXP52f/0Td60n99OTU1Qk6oWmXU";
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
