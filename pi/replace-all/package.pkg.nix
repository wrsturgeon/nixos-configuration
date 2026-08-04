{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "pi-replace-all";
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
    description = "Pi extension providing literal whole-file find and replace";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
