{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "pi-apply-patch";
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
    description = "Pi extension exposing Codex apply_patch as a first-class tool";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
