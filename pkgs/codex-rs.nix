{
  inputs,
  livekitLocked,
  system,
}:
let
  codexPkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ inputs.codex.inputs.rust-overlay.overlays.default ];
  };

  inherit (codexPkgs) lib stdenv;

  cargoToml = builtins.fromTOML (builtins.readFile "${inputs.codex}/codex-rs/Cargo.toml");
  cargoVersion = cargoToml.workspace.package.version;

  version =
    if cargoVersion != "0.0.0" then cargoVersion else "0.0.0-dev+${inputs.codex.shortRev or "dirty"}";

  oldLivekitUrl = "https://github.com/juberti-oai/rust-sdks.git";
  oldLivekitRev = "e2d1d1d230c6fc9df171ccb181423f957bb3c1f0";
  newLivekitUrl = "https://github.com/${livekitLocked.owner}/${livekitLocked.repo}.git";
  newLivekitRev = livekitLocked.rev;

  oldCargoSource = "git+${oldLivekitUrl}?rev=${oldLivekitRev}#${oldLivekitRev}";
  newCargoSource = "git+${newLivekitUrl}?rev=${newLivekitRev}#${newLivekitRev}";

  src = codexPkgs.runCommand "codex-rs-src" { } ''
        cp -r ${inputs.codex}/codex-rs $out
        chmod -R u+w $out

        substituteInPlace $out/realtime-webrtc/Cargo.toml \
          --replace-fail '${oldLivekitUrl}' '${newLivekitUrl}' \
          --replace-fail 'rev = "${oldLivekitRev}"' 'rev = "${newLivekitRev}"'

        substituteInPlace $out/Cargo.lock \
          --replace-fail '${oldCargoSource}' '${newCargoSource}'

        substituteInPlace $out/Cargo.lock \
          --replace-fail 'name = "webrtc-sys"
    version = "0.3.24"
    source = "${newCargoSource}"' 'name = "webrtc-sys"
    version = "0.3.23"
    source = "${newCargoSource}"'
  '';

  rustPlatform = codexPkgs.makeRustPlatform {
    cargo = codexPkgs.rust-bin.stable.latest.minimal;
    rustc = codexPkgs.rust-bin.stable.latest.minimal;
  };

  rustyV8Archive = codexPkgs.fetchurl {
    url = "https://github.com/denoland/rusty_v8/releases/download/v146.4.0/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
    hash = "sha256-5ktNmeSuKTouhGJEqJuAF4uhA4LBP7WRwfppaPUpEVM=";
  };

  parallelism = 4;
in
rustPlatform.buildRustPackage {
  enableParallelBuilding = true;
  env = {
    CARGO_BUILD_JOBS = toString parallelism;
    NIX_BUILD_CORES = toString parallelism;
    PKG_CONFIG_PATH = lib.makeSearchPathOutput "dev" "lib/pkgconfig" (
      [ codexPkgs.openssl ] ++ lib.optionals stdenv.isLinux [ codexPkgs.libcap ]
    );
    RUSTY_V8_ARCHIVE = rustyV8Archive;
  };

  pname = "codex-rs";
  inherit src version;

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "crossterm-0.28.1" = "sha256-6qCtfSMuXACKFb9ATID39XyFDIEMFDmbx6SSmNe+728=";
      "libwebrtc-0.3.26" = "sha256-Nxhh/hEjWVs+ZReOtCpa5Ows2rymeQl0HjBjMyTtfP4=";
      "nucleo-0.5.0" = "sha256-Hm4SxtTSBrcWpXrtSqeO0TACbUxq3gizg1zD/6Yw/sI=";
      "nucleo-matcher-0.3.1" = "sha256-Hm4SxtTSBrcWpXrtSqeO0TACbUxq3gizg1zD/6Yw/sI=";
      "ratatui-0.29.0" = "sha256-HBvT5c8GsiCxMffNjJGLmHnvG77A6cqEL+1ARurBXho=";
      "runfiles-0.1.0" = "sha256-uJpVLcQh8wWZA3GPv9D8Nt43EOirajfDJ7eq/FB+tek=";
      "tokio-tungstenite-0.28.0" = "sha256-hJAkvWxDjB9A9GqansahWhTmj/ekcelslLUTtwqI7lw=";
      "tungstenite-0.27.0" = "sha256-AN5wql2X2yJnQ7lnDxpljNw0Jua40GtmT+w3wjER010=";
    };
  };
  doCheck = false;

  # Patch the workspace Cargo.toml so cargo embeds the build's version.
  postPatch = ''
    sed -i 's/^version = "0\.0\.0"$/version = "${version}"/' Cargo.toml
  '';

  nativeBuildInputs = [
    codexPkgs.cmake
    codexPkgs.llvmPackages.clang
    codexPkgs.llvmPackages.libclang.lib
    codexPkgs.openssl
    codexPkgs.pkg-config
  ]
  ++ lib.optionals stdenv.isLinux [ codexPkgs.libcap ];

  meta = with lib; {
    description = "OpenAI Codex command-line interface rust implementation";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    mainProgram = "codex";
  };
}
