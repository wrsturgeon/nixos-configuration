{
  fd,
  lib,
  makeWrapper,
  nodejs,
  pi,
  ripgrep,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "pi-with-freeform-tools";
  version = pi.version or "0.75.3";

  src = pi;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
    nodejs
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a "$src/lib" "$out/lib"
    chmod -R u+w "$out/lib"

    node ${./patch-pi-freeform-tools.js} "$out/lib/node_modules/@earendil-works/pi-coding-agent"

    install -d "$out/bin"
    makeWrapper ${nodejs}/bin/node "$out/bin/pi" \
      --add-flags "$out/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js" \
      --prefix PATH : ${
        lib.makeBinPath [
          ripgrep
          fd
        ]
      } \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0 \
      --run 'if [ -z "''${JITI_FS_CACHE+x}" ]; then cache_dir="''${TMPDIR:-/tmp}/pi-jiti-$EUID"; if mkdir -p -m 700 "$cache_dir" 2>/dev/null && [ -O "$cache_dir" ]; then chmod 700 "$cache_dir" 2>/dev/null || true; export JITI_FS_CACHE="$cache_dir"; else export JITI_FS_CACHE="$(mktemp -d "''${TMPDIR:-/tmp}/pi-jiti-$EUID.XXXXXX")"; fi; fi'

    runHook postInstall
  '';

  meta = pi.meta // {
    description = "${pi.meta.description or "Pi coding agent"} with Responses freeform tool support";
    mainProgram = "pi";
  };
}
