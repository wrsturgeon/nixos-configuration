{ nodejs, pi }:

pi.overrideAttrs (old: {
  pname = "pi-with-freeform-tools";

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ nodejs ];

  # Patch Pi before its install hook compiles the standalone binary.
  preInstall = ''
    node ${./patch-pi-freeform-tools.js} .
  ''
  + (old.preInstall or "");

  meta = (old.meta or { }) // {
    description = "${old.meta.description or "Pi coding agent"} with Responses freeform tool support";
    mainProgram = "pi";
  };
})
