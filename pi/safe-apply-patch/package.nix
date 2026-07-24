{
  applyPatch,
  lib,
  python3,
  writeShellApplication,
}:

writeShellApplication {
  name = "apply_patch";

  runtimeInputs = [ python3 ];

  text = ''
    exec ${python3}/bin/python3 ${./safe-apply-patch.py} ${applyPatch}/bin/apply_patch "$@"
  '';

  meta = {
    description = "Policy wrapper for apply_patch";
    license = lib.licenses.mit;
    mainProgram = "apply_patch";
    platforms = lib.platforms.linux;
  };
}
