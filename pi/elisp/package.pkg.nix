{
  emacsHome,
  emacsUser,
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "pi-elisp";
  version = "0.1.0";

  src = ./.;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R package.json extensions "$out/"
    substituteInPlace "$out/extensions/elisp.ts" \
      --replace-fail '@EMACSCLIENT@' '/etc/profiles/per-user/${emacsUser}/bin/emacsclient' \
      --replace-fail '@EMACS_HOME@' '${emacsHome}'

    runHook postInstall
  '';

  meta = {
    description = "Pi extension for running freeform Emacs Lisp";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
