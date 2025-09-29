final: prev:
let
  version = "4.21.0";

  pname = "lean";
  tag = "v${version}";
  src = prev.fetchFromGitHub {
    inherit tag;
    owner = "leanprover";
    repo = "lean4";
    hash = "sha256-${
      {
        "4.21.0" = "IZSx7KmkLMEob8BmK/Bi4sS5nh78NHPQPJYgedv2+6Y";
      }
      ."${version}"
    }=";
  };
in

{
  lean4 = prev.stdenv.mkDerivation {
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

    nativeBuildInputs = with final; [
      cmake
      pkg-config
    ];

    buildInputs = with final; [
      gmp
      libuv
      cadical
    ];

    nativeCheckInputs = with final; [
      git
      perl
    ];

    cmakeFlags = [
      "-DUSE_GITHASH=OFF"
      "-DINSTALL_LICENSE=OFF"
      "-DUSE_MIMALLOC=OFF"
    ];

    enableParallelBuilding = true;
  };
}
