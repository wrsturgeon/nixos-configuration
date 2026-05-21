{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "pi-mktemp";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R package.json extensions "$out/"

    runHook postInstall
  '';

  meta = {
    description = "Pi extension for running bash commands in temporary directories populated with provided files";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
