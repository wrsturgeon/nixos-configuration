{
  lib,
  nixpkgsPath,
  stdenvNoCC,
  nixSystem ? stdenvNoCC.hostPlatform.system,
}:

stdenvNoCC.mkDerivation {
  pname = "pi-python";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R README.md package.json extensions "$out/"
    substituteInPlace "$out/extensions/python.ts" \
      --replace-fail "@NIXPKGS_PATH@" "${toString nixpkgsPath}" \
      --replace-fail "@NIX_SYSTEM@" "${nixSystem}"

    runHook postInstall
  '';

  meta = {
    description = "Pi extension providing a Nix-backed Python execution tool";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
