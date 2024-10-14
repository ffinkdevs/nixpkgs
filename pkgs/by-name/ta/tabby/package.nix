{
  config,
  lib,
  rustPlatform,
  fetchFromGitHub,
  nix-update-script,
  stdenv,
  git,
  openssl,
  pkg-config,
  protobuf,
  llama-cpp,
  autoAddDriverRunpath,
  makeWrapper,
  cudaSupport ? config.cudaSupport,
  cudaPackages ? {},
  rocmSupport ? config.rocmSupport,
  vulkanSupport ? config.vulkanSupport,
  darwin,
  metalSupport ? stdenv.isDarwin && stdenv.isAarch64,
  # one of [ null "cpu" "rocm" "cuda" "metal" ];
  acceleration ? "vulkan",
}: let
  inherit (lib) optional optionals flatten;
  # References:
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ll/llama-cpp/package.nix
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/tools/misc/ollama/default.nix

  pname = "tabby";
  version = "0.15.0";

  availableAccelerations = flatten [
    (optional cudaSupport "cuda")
    (optional rocmSupport "rocm")
    (optional vulkanSupport "vulkan")
    (optional metalSupport "metal")
  ];

  warnIfMultipleAccelerationMethods = configured: (
    let
      len = builtins.length configured;
      result =
        if len == 0
        then "cpu"
        else (builtins.head configured);
    in
      lib.warnIf (len > 1) ''
        building tabby with multiple acceleration methods enabled is not
        supported; falling back to `${result}`
      ''
      result
  );

  # If user did not not override the acceleration attribute, then try to use one of
  # - nixpkgs.config.cudaSupport
  # - nixpkgs.config.rocmSupport
  # - metal if (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64)
  # !! warn if multiple acceleration methods are enabled and default to the first one in the list
  featureDevice =
    if (builtins.isNull acceleration)
    then (warnIfMultipleAccelerationMethods availableAccelerations)
    else acceleration;

  warnIfNotLinux = api: (lib.warnIfNot stdenv.hostPlatform.isLinux
    "building tabby with `${api}` is only supported on linux; falling back to cpu"
    stdenv.hostPlatform.isLinux);
  warnIfNotDarwinAarch64 = api: (lib.warnIfNot (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64)
    "building tabby with `${api}` is only supported on Darwin-aarch64; falling back to cpu"
    (stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64));

  validAccel = lib.assertOneOf "tabby.featureDevice" featureDevice ["cpu" "rocm" "cuda" "vulkan" "metal"];

  # TODO(ghthor): there is a bug here where featureDevice could be cuda, but enableCuda is false
  #  The would result in a startup failure of the service module.
  enableRocm = validAccel && (featureDevice == "rocm") && (warnIfNotLinux "rocm");
  enableCuda = validAccel && (featureDevice == "cuda") && (warnIfNotLinux "cuda");
  enableVulkan = validAccel && (featureDevice == "vulkan") && (warnIfNotLinux "vulkan");
  enableMetal = validAccel && (featureDevice == "metal") && (warnIfNotDarwinAarch64 "metal");

  # Ensuring llama-cpp is built with expected acceleration
  llamacppPackage = llama-cpp.override {
    rocmSupport = enableRocm;
    cudaSupport = enableCuda;
    metalSupport = enableMetal;
    vulkanSupport = enableVulkan;
  };

  # TODO(ghthor): some of this can be removed
  darwinBuildInputs = optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
    Foundation
    Accelerate
    CoreVideo
    CoreGraphics
  ]);

  # TODO(ghthor): support linux aarch64
  buildTarget =
    if stdenv.isDarwin
    then "aarch64-apple-darwin"
    else "x86_64-unknown-linux-gnu";
in
  rustPlatform.buildRustPackage rec {
    inherit pname version;
    inherit featureDevice;

    src = fetchFromGitHub {
      owner = "TabbyML";
      repo = "tabby";
      rev = "v${version}";
      hash = "sha256-4IpG/Pq796nVtB0O0bJerwtNjLAU3DY/kEDC58htYR4=";
      fetchSubmodules = true;
    };

    cargoLock = {
      lockFile = ./Cargo.lock;
      # allowBuiltinFetchGit = true;
      outputHashes = {
        "ollama-rs-0.1.9" = "sha256-d6sKUxc8VQbRkVqMOeNFqDdKesq5k32AQShK67y2ssg=";
        "oneshot-0.1.6" = "sha256-PmYuHuNTqToMyMHPRFDUaHUvFkVftx9ZCOBwXj+4Hc4=";
        "ownedbytes-0.7.0" = "sha256-p0+ohtW0VLmfDTZw/LfwX2gYfuYuoOBcE+JsguK7Wn8=";
        "tree-sitter-solidity-1.2.6" = "sha256-S00hdzMoIccPYBEvE092/RIMnG8YEnDGk6GJhXlr4ng=";
        "tree-sitter-c-0.21.3" = "sha256-ucbHLS2xyGo1uyKZv/K1HNXuMo4GpTY327cgdVS9F3c=";
        "tree-sitter-cpp-0.22.1" = "sha256-3akSuQltFMF6I32HwRU08+Hcl9ojxPGk2ZuOX3gAObw=";
      };
    };

    # https://github.com/TabbyML/tabby/blob/v0.7.0/.github/workflows/release.yml#L39
cargoBuildType = "release";
    cargoBuildFlags = [
   
      "--no-default-features"
      "--target"
      buildTarget
      "--features"
      "prod"
      "--package"
      "tabby"
    ];

    OPENSSL_NO_VENDOR = 1;

    nativeBuildInputs =
      [
        pkg-config
        protobuf
        git
        makeWrapper
      ]
      ++ optionals enableCuda [
        autoAddDriverRunpath
      ];

    buildInputs =
      [openssl]
      ++ optionals stdenv.isDarwin darwinBuildInputs;
    # patches = [ ./0001-nix-build-use-nix-native-llama-cpp-package.patch ];

    postInstall = ''
      wrapProgram $out/bin/tabby \
        --prefix PATH : ${lib.makeBinPath [llamacppPackage]}
    '';
    # Fails with:
    # file cannot create directory: /var/empty/local/lib64/cmake/Llama
    doCheck = false;

    passthru.updateScript = nix-update-script {};

    meta = with lib; {
      homepage = "https://github.com/TabbyML/tabby";
      changelog = "https://github.com/TabbyML/tabby/releases/tag/v${version}";
      description = "Self-hosted AI coding assistant";
      mainProgram = "tabby";
      license = licenses.asl20;
      maintainers = [maintainers.ghthor];
      broken = stdenv.isDarwin && !stdenv.isAarch64;
    };
  }
