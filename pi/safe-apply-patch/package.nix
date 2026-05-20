{
  codex,
  lib,
  python3,
  writeShellApplication,
}:

writeShellApplication {
  name = "apply_patch";

  runtimeInputs = [ python3 ];

  text = ''
    exec ${python3}/bin/python3 ${./safe-apply-patch.py} ${codex}/bin/.codex-wrapped "$@"
  '';

  meta = {
    description = "Policy wrapper for Codex apply_patch";
    license = lib.licenses.mit;
    mainProgram = "apply_patch";
    platforms = lib.platforms.linux;
  };
}
