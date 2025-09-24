{ pkgs, ... }:
let
  version = "4.21.0";

  hashes = {
    "4.21.0" = "IZSx7KmkLMEob8BmK/Bi4sS5nh78NHPQPJYgedv2+6Y";
  };

  pname = "lean";
  tag = "v${version}";
  src = pkgs.fetchFromGitHub {
    inherit tag;
    owner = "leanprover";
    repo = "lean4";
    hash = "sha256-${hashes."${version}"}=";
  };
in

pkgs.stdenv.mkDerivation {
  inherit pname src version;

  postPatch = ''
    substituteInPlace src/CMakeLists.txt \
      --replace-fail 'set(GIT_SHA1 "")' 'set(GIT_SHA1 "${tag}")'

    # Remove tests that fails in sandbox.
    # It expects `sourceRoot` to be a git repository.
    rm -rf src/lake/examples/git/
  '';

  preConfigure = ''
    patchShebangs stage0/src/bin/ src/bin/
  '';

  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
  ];

  buildInputs = with pkgs; [
    gmp
    libuv
    cadical
  ];

  nativeCheckInputs = with pkgs; [
    git
    perl
  ];

  cmakeFlags = [
    "-DUSE_GITHASH=OFF"
    "-DINSTALL_LICENSE=OFF"
    "-DUSE_MIMALLOC=OFF"
  ];

  enableParallelBuilding = true;
}
