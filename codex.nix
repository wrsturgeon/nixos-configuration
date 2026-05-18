{
  inputs,
  lib,
  pkgs,
  username ? null,
}:
let
  inherit (pkgs) stdenv;

  pname = "codex-desktop";
  version = "26.513.31313";
  electronVersion = "42.0.1";

  electronPlatform =
    {
      x86_64-linux = {
        arch = "x64";
        hash = "sha256-4bi1uG0//2nis1AlhjY9OECF7gV4vQQfpZFf0LVXxPE=";
      };
      aarch64-linux = {
        arch = "arm64";
        hash = "sha256-oIpOaROATrBc6nmNi9CvrOTRuI6dB9uGt3nqSkSL4HA=";
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "${pname} is only wired for x86_64-linux and aarch64-linux");

  electronZip = pkgs.fetchurl {
    url = "https://github.com/electron/electron/releases/download/v${electronVersion}/electron-v${electronVersion}-linux-${electronPlatform.arch}.zip";
    inherit (electronPlatform) hash;
  };

  electronHeaders = pkgs.fetchurl {
    url = "https://artifacts.electronjs.org/headers/dist/v${electronVersion}/node-v${electronVersion}-headers.tar.gz";
    hash = "sha256-yQBrv98qtbQ8cdZpuqx2uyP1mkIAVhLlUFjI/vxh9gA=";
  };

  nativeModulesPackageJson = pkgs.writeText "package.json" (
    builtins.toJSON {
      name = "codex-desktop-native-modules";
      version = "0.0.0";
      private = true;
      dependencies = {
        "@electron/rebuild" = "4.0.4";
        "better-sqlite3" = "12.9.0";
        "electron" = electronVersion;
        "node-abi" = "^4.31.0";
        "node-pty" = "1.1.0";
      };
    }
  );

  # Lockfile for exactly the native modules embedded in Codex ${version}. The
  # rest of the app comes from inputs.codex-dmg; this only lets Nix fetch and
  # rebuild better-sqlite3/node-pty for Electron's Linux ABI.
  nativeModulesPackageLock = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/ilysenko/codex-desktop-linux/81dbd59673b986065a248c8df23f5d7d237942b0/nix/native-modules/package-lock.json";
    hash = "sha256-yKRPBw0txhpkDxMRcVMC56SJ0fo7jg7hLGvnXG14kKI=";
  };

  nativeModulesSrc = pkgs.runCommand "codex-desktop-native-modules-src" { } ''
    mkdir -p "$out"
    cp ${nativeModulesPackageJson} "$out/package.json"
    cp ${nativeModulesPackageLock} "$out/package-lock.json"
  '';

  betterSqliteElectron42Patch = pkgs.writeText "patch-better-sqlite3-electron-42.js" ''
    const fs = require("fs");
    const path = require("path");

    const moduleDir = process.argv[2];
    const files = {
      main: path.join(moduleDir, "src/better_sqlite3.cpp"),
      helpers: path.join(moduleDir, "src/util/helpers.cpp"),
      macros: path.join(moduleDir, "src/util/macros.cpp"),
    };

    function replaceOnce(file, needle, replacement) {
      const source = fs.readFileSync(file, "utf8");
      if (source.includes(replacement)) return;
      if (!source.includes(needle)) {
        throw new Error(`Could not find better-sqlite3 Electron 42 patch point in ''${file}`);
      }
      fs.writeFileSync(file, source.replace(needle, replacement));
    }

    replaceOnce(
      files.main,
      "v8::Local<v8::External> data = v8::External::New(isolate, addon);",
      "v8::Local<v8::External> data = BETTER_SQLITE3_EXTERNAL_NEW(isolate, addon);",
    );
    replaceOnce(
      files.macros,
      `#define EasyIsolate v8::Isolate* isolate = v8::Isolate::GetCurrent()
    #define OnlyIsolate info.GetIsolate()
    #define OnlyContext isolate->GetCurrentContext()
    #define OnlyAddon static_cast<Addon*>(info.Data().As<v8::External>()->Value())`,
      `#if defined(V8_MAJOR_VERSION) && V8_MAJOR_VERSION >= 14
    #define BETTER_SQLITE3_EXTERNAL_POINTER_TAG v8::kExternalPointerTypeTagDefault
    #define BETTER_SQLITE3_EXTERNAL_NEW(isolate, value) v8::External::New((isolate), (value), BETTER_SQLITE3_EXTERNAL_POINTER_TAG)
    #define BETTER_SQLITE3_EXTERNAL_VALUE(external) ((external)->Value(BETTER_SQLITE3_EXTERNAL_POINTER_TAG))
    #else
    #define BETTER_SQLITE3_EXTERNAL_NEW(isolate, value) v8::External::New((isolate), (value))
    #define BETTER_SQLITE3_EXTERNAL_VALUE(external) ((external)->Value())
    #endif

    #define EasyIsolate v8::Isolate* isolate = v8::Isolate::GetCurrent()
    #define OnlyIsolate info.GetIsolate()
    #define OnlyContext isolate->GetCurrentContext()
    #define OnlyAddon static_cast<Addon*>(BETTER_SQLITE3_EXTERNAL_VALUE(info.Data().As<v8::External>()))`,
    );
    replaceOnce(
      files.helpers,
      `		func,
    		0,
    		data`,
      `		func,
    		nullptr,
    		data`,
    );
  '';

  codexNativeModules = pkgs.buildNpmPackage {
    pname = "codex-desktop-native-modules";
    version = electronVersion;
    src = nativeModulesSrc;

    npmDepsHash = "sha256-8VdVGPLkudlKSXyWuYrZV3nuDYEhG50u65TI5z5XyvE=";
    npmFlags = [ "--ignore-scripts" ];

    nativeBuildInputs = with pkgs; [
      gcc
      gnumake
      nodejs
      python3
    ];

    dontNpmBuild = true;

    buildPhase = ''
      runHook preBuild

      mkdir -p "$TMPDIR/electron-headers"
      tar -xzf ${electronHeaders} -C "$TMPDIR/electron-headers" --strip-components=1

      export npm_config_nodedir="$TMPDIR/electron-headers"
      export NPM_CONFIG_NODEDIR="$TMPDIR/electron-headers"

      node ${betterSqliteElectron42Patch} "$PWD/node_modules/better-sqlite3"
      node "$PWD/node_modules/@electron/rebuild/lib/cli.js" \
        -v ${electronVersion} \
        --force \
        --module-dir "$PWD" \
        --dist-url "file://$TMPDIR/electron-headers"

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -R node_modules/better-sqlite3 "$out/better-sqlite3"
      cp -R node_modules/node-pty "$out/node-pty"

      find "$out/better-sqlite3/build" -type f ! -name "*.node" -delete 2>/dev/null || true
      find "$out/node-pty/build" -type f ! -name "*.node" -delete 2>/dev/null || true
      find "$out" -type d -empty -delete 2>/dev/null || true
      find "$out" -type f -name "*.target.mk" -delete 2>/dev/null || true

      runHook postInstall
    '';
  };

  electronLibs = with pkgs; [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libX11
    libxcb
    libXcomposite
    libxcursor
    libXdamage
    libXext
    libXfixes
    libxi
    libxkbcommon
    libXrandr
    libxscrnsaver
    libxtst
    mesa
    nspr
    nss
    pango
    systemd
    wayland
  ];

  electronLibPath = lib.makeLibraryPath electronLibs;
  runtimeLibPath = lib.makeLibraryPath (
    with pkgs;
    [
      libxcrypt-legacy
      stdenv.cc.cc.lib
      zlib
    ]
  );
  launcherPath =
    lib.makeBinPath (
      with pkgs;
      [
        bash
        coreutils
        gnugrep
        gnused
        nodejs
        procps
        python3
        xdg-utils
      ]
    )
    + ":/run/current-system/sw/bin"
    + lib.optionalString (username != null) ":/etc/profiles/per-user/${username}/bin";

  patchApp = pkgs.writeText "patch-codex-desktop-linux.js" ''
    const fs = require("fs");
    const path = require("path");

    const appDir = process.argv[2];
    const desktopName = "codex-desktop.desktop";

    function read(file) {
      return fs.readFileSync(file, "utf8");
    }

    function write(file, text) {
      fs.writeFileSync(file, text, "utf8");
    }

    function replace(file, label, transform) {
      const before = read(file);
      const after = transform(before);
      if (after !== before) {
        write(file, after);
      }
      return after !== before;
    }

    function replaceRequired(file, needle, replacement, label) {
      replace(file, label, (source) => {
        if (source.includes(replacement)) return source;
        if (!source.includes(needle)) {
          throw new Error(`Could not find ''${label} patch point in ''${file}`);
        }
        return source.replace(needle, replacement);
      });
    }

    const packageJsonPath = path.join(appDir, "package.json");
    const packageJson = JSON.parse(read(packageJsonPath));
    packageJson.desktopName = desktopName;
    write(packageJsonPath, `''${JSON.stringify(packageJson, null, 2)}\n`);

    const bootstrapPath = path.join(appDir, ".vite/build/bootstrap.js");
    if (fs.existsSync(bootstrapPath)) {
      replace(
        bootstrapPath,
        "Linux multi-instance lock",
        (source) => source.replace(
          "if(!(!S||n.app.requestSingleInstanceLock()))",
          "if(!(!S||process.platform===`linux`&&process.env.CODEX_LINUX_MULTI_LAUNCH===`1`||n.app.requestSingleInstanceLock()))",
        ),
      );
    }

    const webviewAssets = path.join(appDir, "webview/assets");
    for (const name of fs.readdirSync(webviewAssets)) {
      if (!/^index-.*\.js$/.test(name)) continue;
      const file = path.join(webviewAssets, name);
      replace(file, "Linux app sunset gate", (source) => {
        const disabled = /if\(!1&&([A-Za-z_$][\w$]*)\(`2929582856`\)\)\{/u;
        const enabled = /if\(([A-Za-z_$][\w$]*)\(`2929582856`\)\)\{/u;
        if (disabled.test(source)) return source;
        if (enabled.test(source)) return source.replace(enabled, "if(!1&&$1(`2929582856`)){");
        if (source.includes("2929582856")) {
          throw new Error(`Could not find Linux app sunset gate patch point in ''${file}`);
        }
        return source;
      });
    }

    const buildDir = path.join(appDir, ".vite/build");
    const mainName = fs.readdirSync(buildDir).find((name) => /^main(?:-[^.]+)?\.js$/.test(name));
    const iconName = fs.readdirSync(webviewAssets).find((name) => /^app-.*\.png$/.test(name));

    if (mainName && iconName) {
      const mainPath = path.join(buildDir, mainName);
      const iconExpression = `process.resourcesPath+\`/../content/webview/assets/''${iconName}\``;

      replaceRequired(
        mainPath,
        "...process.platform===`win32`?{autoHideMenuBar:!0}:{},",
        `...process.platform===\`win32\`||process.platform===\`linux\`?{autoHideMenuBar:!0,...process.platform===\`linux\`?{icon:''${iconExpression}}:{}}:{},`,
        "Linux BrowserWindow options",
      );

      replace(mainPath, "Linux menu visibility", (source) =>
        source.replace(
          /process\.platform===`win32`&&([A-Za-z_$][\w$]*)\.removeMenu\(\),/g,
          "process.platform===`linux`&&$1.setMenuBarVisibility(!1),process.platform===`win32`&&$1.removeMenu(),",
        )
      );

      replace(mainPath, "Linux setIcon", (source) => {
        if (source.includes(`setIcon(''${iconExpression})`)) return source;
        return source.replace(
          /([A-Za-z_$][\w$]*)\.once\(`ready-to-show`,\(\)=>\{/,
          `process.platform===\`linux\`&&$1.setIcon(''${iconExpression}),$&`,
        );
      });
    }
  '';

  launcher = pkgs.writeShellScript "codex-desktop-start" ''
    set -euo pipefail

    app_dir="$(cd -- "$(dirname -- "''${BASH_SOURCE[0]}")" && pwd)"
    port="''${CODEX_WEBVIEW_PORT:-5175}"
    case "$port" in
      ""|*[!0-9]*) echo "CODEX_WEBVIEW_PORT must be a TCP port number" >&2; exit 1 ;;
    esac

    log_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/codex-desktop"
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/codex-desktop"
    config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/codex-desktop"
    mkdir -p "$log_dir" "$state_dir" "$config_dir"

    export CODEX_LINUX_APP_ID="codex-desktop"
    export CODEX_LINUX_APP_DISPLAY_NAME="Codex Desktop"
    export CODEX_LINUX_WEBVIEW_PORT="$port"
    export CODEX_LINUX_SETTINGS_FILE="$config_dir/settings.json"
    export ELECTRON_RENDERER_URL="http://127.0.0.1:$port/"
    export CHROME_DESKTOP="codex-desktop.desktop"
    export CODEX_ELECTRON_RESOURCES_PATH="$app_dir/resources"
    export CODEX_BROWSER_USE_NODE_PATH="${pkgs.nodejs}/bin/node"
    export NODE_REPL_NODE_PATH="$CODEX_BROWSER_USE_NODE_PATH"

    if [ -z "''${CODEX_CLI_PATH:-}" ]; then
      CODEX_CLI_PATH="$(command -v codex || true)"
      export CODEX_CLI_PATH
    fi

    server_pid=""
    if ! (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      (
        cd "$app_dir/content/webview"
        exec ${pkgs.python3}/bin/python3 -m http.server "$port" --bind 127.0.0.1
      ) >>"$log_dir/webview.log" 2>&1 &
      server_pid="$!"
      for _ in $(seq 1 100); do
        (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
        sleep 0.05
      done
    fi

    cleanup() {
      if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
      fi
    }
    trap cleanup EXIT

    electron_args=(
      --no-sandbox
      --disable-gpu-sandbox
      --enable-features=WaylandWindowDecorations
    )

    if [ -n "''${CODEX_ELECTRON_OZONE_PLATFORM:-}" ]; then
      electron_args+=(--ozone-platform="$CODEX_ELECTRON_OZONE_PLATFORM")
    elif [ -n "''${WAYLAND_DISPLAY:-}" ]; then
      electron_args+=(--ozone-platform=wayland)
    elif [ -n "''${DISPLAY:-}" ]; then
      electron_args+=(--ozone-platform=x11)
    else
      electron_args+=(--ozone-platform-hint=auto)
    fi

    if [ "''${CODEX_ELECTRON_DISABLE_GPU_COMPOSITING:-1}" != "0" ]; then
      electron_args+=(--disable-gpu-compositing)
    fi

    "$app_dir/electron" "''${electron_args[@]}" "$@" >>"$log_dir/electron.log" 2>&1
  '';
in
stdenv.mkDerivation {
  inherit pname version;

  src = inputs.codex-dmg;

  nativeBuildInputs = with pkgs; [
    _7zz
    asar
    makeWrapper
    nodejs
    patchelf
    python3
    unzip
  ];

  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    app_root="$out/opt/codex-desktop"
    resources_dir="$app_root/resources"
    extracted_app="$TMPDIR/app-extracted"
    dmg_dir="$TMPDIR/dmg"

    mkdir -p "$app_root" "$resources_dir" "$dmg_dir"
    7zz x -y -snl "$src" -o"$dmg_dir" >/dev/null

    app_dir="$(find "$dmg_dir" -maxdepth 3 -name '*.app' -type d | head -n 1)"
    [ -n "$app_dir" ] || { echo "Codex.app not found in DMG" >&2; exit 1; }

    unzip -q ${electronZip} -d "$app_root"

    cp "$app_dir/Contents/Resources/app.asar" "$resources_dir/app.asar"
    cp -R "$app_dir/Contents/Resources/app.asar.unpacked" "$resources_dir/app.asar.unpacked"

    asar extract "$resources_dir/app.asar" "$extracted_app"
    rm -rf "$extracted_app/node_modules/better-sqlite3" "$extracted_app/node_modules/node-pty"
    cp -R ${codexNativeModules}/better-sqlite3 "$extracted_app/node_modules/better-sqlite3"
    cp -R ${codexNativeModules}/node-pty "$extracted_app/node_modules/node-pty"
    chmod -R u+w "$extracted_app/node_modules/better-sqlite3" "$extracted_app/node_modules/node-pty"

    node ${patchApp} "$extracted_app"

    mkdir -p "$app_root/content/webview"
    cp -R "$extracted_app/webview/." "$app_root/content/webview/"
    if [ -f "$app_root/content/webview/index.html" ]; then
      substituteInPlace "$app_root/content/webview/index.html" \
        --replace-fail "--startup-background: transparent" "--startup-background: #1e1e1e"
    fi

    rm -f "$resources_dir/app.asar"
    rm -rf "$resources_dir/app.asar.unpacked"
    (cd "$extracted_app" && find . -type f | LC_ALL=C sort | sed 's#^\./##') > "$TMPDIR/app.asar.ordering"
    asar pack "$extracted_app" "$resources_dir/app.asar" \
      --ordering "$TMPDIR/app.asar.ordering" \
      --unpack "{*.node,*.so,*.dylib}" >/dev/null

    rm -rf "$extracted_app"

    if [ -f "$resources_dir/node_repl" ]; then
      patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
        --set-rpath "${
          lib.makeLibraryPath [
            stdenv.cc.cc.lib
            pkgs.glibc
          ]
        }" \
        "$resources_dir/node_repl" || true
    fi

    patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
      --set-rpath "$app_root:${electronLibPath}" \
      "$app_root/electron"

    for exe in chrome_crashpad_handler chrome-sandbox; do
      if [ -f "$app_root/$exe" ]; then
        patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" \
          "$app_root/$exe" || true
      fi
    done

    find "$app_root" -maxdepth 1 -name "*.so*" -type f | while read -r so; do
      patchelf --set-rpath "${electronLibPath}" "$so" 2>/dev/null || true
    done

    install -Dm0755 ${launcher} "$app_root/start.sh"
    install -d "$out/bin"
    makeWrapper "$app_root/start.sh" "$out/bin/codex-desktop" \
      --prefix PATH : "${launcherPath}" \
      --prefix LD_LIBRARY_PATH : "${electronLibPath}" \
      --prefix LD_LIBRARY_PATH : "${runtimeLibPath}"

    icon="$(find "$app_root/content/webview/assets" -maxdepth 1 -name 'app-*.png' -type f | head -n 1)"
    if [ -n "$icon" ]; then
      install -Dm0644 "$icon" "$out/share/icons/hicolor/256x256/apps/codex-desktop.png"
    fi

    install -Dm0644 /dev/stdin "$out/share/applications/codex-desktop.desktop" <<EOF
    [Desktop Entry]
    Name=Codex Desktop
    Comment=Codex desktop app converted from the official DMG
    Exec=$out/bin/codex-desktop %u
    Icon=codex-desktop
    Terminal=false
    Type=Application
    Categories=Development;
    MimeType=x-scheme-handler/codex;x-scheme-handler/codex-browser-sidebar;
    StartupNotify=true
    StartupWMClass=Codex
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Codex Desktop for Linux, converted from the official Codex DMG";
    homepage = "https://codex.openai.com/";
    license = lib.licenses.unfree;
    mainProgram = "codex-desktop";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
