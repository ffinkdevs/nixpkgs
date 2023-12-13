{
  generateProtobufCode,
  version,
  zitadelRepo,
}: {
  mkYarnPackage,
  fetchYarnDeps,
  lib,
}: let
  protobufGenerated = generateProtobufCode {
    pname = "zitadel-console";
    workDir = "console";
    bufArgs = "../proto --include-imports --include-wkt";
    outputPath = "src/app/proto";
    hash = "sha256-jaj3ZtwYL69KZWXv4bXwmqtZVkrRJEbZJM+0ZkKMobU=";
  };
in
  mkYarnPackage rec {
    name = "zitadel-console";
    inherit version;

    src = "${zitadelRepo}/console";

    packageJSON = "${src}/package.json";
    offlineCache = fetchYarnDeps {
      yarnLock = "${src}/yarn.lock";
      hash = "sha256-cfo2WLSbfU8tYADjF7j9zTLNsboVThF6MUBrb49MrII=";
    };

    postPatch = ''
      substituteInPlace src/styles.scss \
        --replace "/node_modules/flag-icons" "flag-icons"

      substituteInPlace angular.json \
        --replace "./node_modules/tinycolor2" "../../node_modules/tinycolor2"
    '';

    buildPhase = ''
      mkdir deps/console/src/app/proto
      cp -r ${protobufGenerated}/* deps/console/src/app/proto/
      yarn --offline build
    '';

    installPhase = ''
      cp -r deps/console/dist/console $out
    '';

    doDist = false;
  }
