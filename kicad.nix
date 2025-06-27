{ inputs, pkgs, ... }:
let
  unwrapped = pkgs.stdenv.mkDerivation {
    pname = "kicad-unwrapped";
    version = "git";
    src = inputs.kicad-src;
    enableParallelBuilding = true;

    nativeBuildInputs =
      with pkgs;
      [
        boost
        cairo
        cmake
        curl
        harfbuzz
        glew
        glm
        gtk3
        libgit2
        libngspice
        libsecret
        makeWrapper
        nng
        opencascade-occt
        pkg-config
        protobuf
        python3
        swig
        unixODBC
        zlib
        zstd
      ]
      ++ (with pkgs.python3Packages; [ wxpython ])
      ++ [
        (pkgs.wxGTK32.overrideAttrs (old: {
          configureFlags = old.configureFlags ++ [ "--disable-glcanvasegl" ];
        }))
      ];

    configurePhase = ''
      mkdir -p build/release
      cd build/release
      cmake -DCMAKE_INSTALL_PREFIX=$out -DCMAKE_BUILD_TYPE=RelWithDebInfo -DKICAD_IPC_API=OFF -DKICAD_USE_EGL=OFF -DOCC_INCLUDE_DIR=${pkgs.opencascade-occt}/include/opencascade ../../
    '';
  };
in
pkgs.stdenv.mkDerivation {
  pname = "kicad";
  version = "git";
  src = unwrapped;
  enableParallelBuilding = true;

  buildPhase = ''
    ls -A
    exit 1
  '';

  postFixupPhase = ''
    for f in $out/bin/*; do
      if [[ -x $f ]]; then
        wrapProgram $f --suffix LD_LIBRARY_PATH : $out/lib
      fi
    done
  '';
}
