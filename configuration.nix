{
  config,
  default-font,
  github-username,
  home,
  hostname,
  inputs,
  keyboard,
  lib,
  location,
  nh-clean-all-flags,
  nh-os-flags,
  nrs,
  ollama-host,
  ollama-port,
  pkgs,
  stateVersion,
  unfree-regex,
  username,
  ...
}:
let
  inherit (pkgs) stdenv;
  inherit (stdenv.targetPlatform) system;

  kernelPackages = pkgs.linuxPackages_latest;
  # linux-version-drv = stdenvNoCC.mkDerivation {
  #   dontBuild = true;
  #   dontConfigure = true;
  #   installPhase = ''
  #     set -euxo pipefail
  #     export VERSION="$(cat Makefile | grep '^VERSION ' | head -n 1 | cut -d '=' -f 2- | xargs)"
  #     export PATCHLEVEL="$(cat Makefile | grep '^PATCHLEVEL ' | head -n 1 | cut -d '=' -f 2- | xargs)"
  #     export SUBLEVEL="$(cat Makefile | grep '^SUBLEVEL ' | head -n 1 | cut -d '=' -f 2- | xargs)"
  #     export EXTRAVERSION="$(cat Makefile | grep '^EXTRAVERSION ' | head -n 1 | cut -d '=' -f 2- | xargs)"
  #     export NAME="$(cat Makefile | grep '^NAME ' | head -n 1 | cut -d '=' -f 2- | xargs)"
  #     mkdir $out
  #     echo -n "''${VERSION}.''${PATCHLEVEL}.''${SUBLEVEL}" > $out/version
  #     if [ ! -z "''${EXTRAVERSION}" ]
  #     then
  #         echo -n "''${EXTRAVERSION}" >> $out/version
  #     fi
  #     echo -n "''${NAME}" > $out/aka
  #   '';
  #   name = "linux-version";
  #   src = inputs.linux-src;
  # };
  # linux-version = builtins.readFile "${linux-version-drv}/version";
  # linux-aka = builtins.readFile "${linux-version-drv}/aka";
  # linux = pkgs.buildLinux {
  #   extraMeta.branch = "master";
  #   ignoreConfigErrors = true;
  #   modDirVersion = builtins.trace "Living dangerously on Linux master@v${linux-version} a.k.a. ${linux-aka}" linux-version;
  #   src = inputs.linux-src;
  #   version = linux-version;
  # };
  # kernelPackages = lib.recurseIntoAttrs (pkgs.linuxPackagesFor linux);

  hyprPackages = inputs.hyprland.packages.${system};
  theme = import ./theme.nix {
    caelestiaCliSrc = inputs.caelestia-shell.inputs.caelestia-cli.outPath;
    inherit lib pkgs;
    inherit (inputs) onedark zed-one;
  };
  desktopTheme = theme.active;
  appTheme = theme.defaultAppTheme;
  caelestiaCli =
    theme.patchCaelestiaCli
      inputs.caelestia-shell.inputs.caelestia-cli.packages.${system}.caelestia-cli;

  rebuild-nixos-service-name = "rebuild-nixos";
in
{
  age.secrets =
    let
      generatedSecrets = builtins.mapAttrs (_: file: { inherit file; }) (
        let
          filetypes = builtins.readDir ./secrets;
          ls = builtins.attrNames filetypes;
          ages = builtins.filter (lib.strings.hasSuffix ".age") ls;
        in
        builtins.listToAttrs (
          map (f: {
            name = lib.strings.removeSuffix ".age" f;
            value = ./secrets/${f};
          }) ages
        )
      );
    in
    generatedSecrets
    // {
      gh-pat = generatedSecrets.gh-pat // {
        owner = username;
      };
    };

  boot = {
    inherit kernelPackages;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    tmp.cleanOnBoot = true;
  };

  console = {
    earlySetup = true;
    font = "${pkgs.terminus_font}/share/consolefonts/ter-u12n.psf.gz";
    useXkbConfig = true;
  };

  environment = {
    interactiveShellInit = ''
      if [ -r ${config.age.secrets.gh-pat.path} ]; then
        export GH_TOKEN="$(cat ${config.age.secrets.gh-pat.path})"
        export GITHUB_TOKEN="$GH_TOKEN"
      fi
    '';
    shellAliases = {
      cb = "cargo build";
      cl = "cargo clippy --all-features --all-targets --color=always 2>&1 | head -n 64";
      cm = "cargo miri run";
      cmt = "cargo miri test";
      cr = "cargo run";
      ct = "cargo test";
      nb = "nix build -L";
      nf = "nix fmt";
      nr = "nix run -L";
      nrl = "nix run -L --no-substitute --no-use-registries"; # for "[n]ix [r]un [l]ocal"
      nrs = "systemctl start ${lib.strings.escapeShellArg rebuild-nixos-service-name} && journalctl -f -u ${lib.strings.escapeShellArg rebuild-nixos-service-name}"; # for "[n]ixos-[r]ebuild [s]witch"
    };
    systemPackages =
      (map (flake: flake.packages.${system}.default) (with inputs; [ agenix ]))
      ++ (with pkgs; [
        binutils # ld, ar, objdump, etc.
        brightnessctl
        btop
        bubblewrap
        comma
        coreutils-full # ls, cp, pwd, etc.
        cowsay # for fun
        egl-wayland # NVIDIA (https://wiki.hypr.land/Nvidia/)
        fortune # for fun
        gh
        gnumake
        jq # JSON utils
        killall
        ncdu
        nemo
        net-tools # ifconfig, etc.
        nixfmt
        openssl
        pkg-config
        playerctl
        python3
        ripgrep # rg
        tmux
        tree
        unzip
        valgrind
        wl-clipboard
        zip
      ])
      ++ (with stdenv; [ cc ])
      ++ (with pkgs.nvtopPackages; [ full ])
      ++ (with inputs.llm-agents.packages.${system}; [
        codex
        pi
      ]);
    # usrbinenv = null; # https://github.com/NixOS/nix/issues/1205
    variables = {
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      EDITOR = "nvim";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      LIBVA_DRIVER_NAME = "nvidia";
      NIXOS_OZONE_WL = "1";
      NVD_BACKEND = "direct";
      OLLAMA_API_BASE = "http://\${OLLAMA_HOST}";
      OLLAMA_HOST = "${ollama-host}:${toString ollama-port}";
      OPENCODE_EXPERIMENTAL = "true";
      OPENSSL_DIR = "${pkgs.openssl}";
      XKB_DEFAULT_LAYOUT = keyboard.layout;
      XKB_DEFAULT_VARIANT = keyboard.variant;
    };
  };

  fonts = {
    fontconfig = {
      defaultFonts = {
        sansSerif = [
          default-font
          "Inter"
        ];
        serif = [
          "Blanco Trial"
          "Source Serif 4"
        ];
        monospace = [ "Iosevka Custom" ];
      };
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <dir>/var/lib/local-fonts/absans</dir>
          <dir>/var/lib/local-fonts/blanco</dir>
          <dir>/var/lib/local-fonts/foss-serif</dir>
          <dir>/var/lib/local-fonts/martina-plantijn</dir>
          <dir>/var/lib/local-fonts/signifier</dir>
          <dir>/var/lib/local-fonts/taurus-grotesk</dir>

          <alias binding="strong">
            <family>system-ui</family>
            <prefer>
              <family>${default-font}</family>
              <family>Inter</family>
            </prefer>
          </alias>

          <alias binding="strong">
            <family>ui-sans-serif</family>
            <prefer>
              <family>${default-font}</family>
              <family>Inter</family>
            </prefer>
          </alias>
        </fontconfig>
      '';
    };
    packages =
      let
        iosevka = pkgs.iosevka.override {
          # From <https://typeof.net/Iosevka/customizer>:
          privateBuildPlan = ''
            [buildPlans.IosevkaCustom]
            family = "Iosevka Custom"
            spacing = "term"
            serifs = "sans"
            noCvSs = false
            exportGlyphNames = true
            buildTextureFeature = true

            [buildPlans.IosevkaCustom.variants]
            inherits = "ss08"

            [buildPlans.IosevkaCustom.ligations]
            inherits = "haskell"

            [buildPlans.IosevkaCustom.widths.Normal]
            shape = 500
            menu = 5
            css = "normal"

            [buildPlans.IosevkaCustom.slopes.Upright]
            angle = 0
            shape = "upright"
            menu = "upright"
            css = "normal"

            [buildPlans.IosevkaCustom.slopes.Italic]
            angle = 9.4
            shape = "italic"
            menu = "italic"
            css = "italic"
          '';
          set = "Custom";
        };
        bluu-next = pkgs.stdenvNoCC.mkDerivation {
          pname = "bluu-next";
          version = "unstable-2019-07-04";
          src = inputs.bluu-next;

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            install -Dm644 -t $out/share/fonts/opentype Fonts/*.otf
            runHook postInstall
          '';
        };
        google-fonts = import ./google-fonts.nix { inherit inputs pkgs; };
        instrument-sans-90 =
          let
            fonttools = pkgs.python3.withPackages (ps: [ ps.fonttools ]);
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "instrument-sans-90";
            version = "unstable-2026-03-13";
            src = google-fonts;

            dontConfigure = true;
            dontBuild = true;

            nativeBuildInputs = [ fonttools ];

            installPhase = ''
                            runHook preInstall

                            install -d $out/share/fonts/truetype

                            make_instance() {
                              local input="$1"
                              local output="$2"
                              local style="$3"
                              local ps_suffix="$4"
                              local weight="$5"
                              local source_weight=$((weight + 25))

                              fonttools varLib.instancer "$input" wdth=90 wght="$source_weight" --static --output "$output"

                              python - "$output" "$style" "$ps_suffix" "$weight" <<'PY'
              from fontTools.ttLib import TTFont
              import sys

              path, style, ps_suffix, nominal_weight = sys.argv[1:]
              family = "Instrument Sans 90"
              ps_family = "InstrumentSans90"
              full_name = f"{family} {style}"
              postscript_name = f"{ps_family}-{ps_suffix}"
              values = {
                  1: family,
                  2: style,
                  4: full_name,
                  6: postscript_name,
                  16: family,
                  17: style,
                  25: ps_family,
              }
              font = TTFont(path)
              if "OS/2" in font:
                  font["OS/2"].usWeightClass = int(nominal_weight)
              for record in font["name"].names:
                  value = values.get(record.nameID)
                  if value is None:
                      continue
                  record.string = value.encode(record.getEncoding(), errors="replace")
              font.save(path)
              PY
                            }

                            regular="$src/share/fonts/truetype/InstrumentSans[wdth,wght].ttf"
                            italic="$src/share/fonts/truetype/InstrumentSans-Italic[wdth,wght].ttf"

                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-Thin.ttf" Thin Thin 100
                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-ExtraLight.ttf" "ExtraLight" ExtraLight 200
                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-Light.ttf" Light Light 300
                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-Regular.ttf" Regular Regular 400
                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-Medium.ttf" Medium Medium 500
                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-SemiBold.ttf" SemiBold SemiBold 600
                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-Bold.ttf" Bold Bold 700
                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-ExtraBold.ttf" ExtraBold ExtraBold 800
                            make_instance "$regular" "$out/share/fonts/truetype/InstrumentSans90-Black.ttf" Black Black 900

                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-ThinItalic.ttf" "Thin Italic" ThinItalic 100
                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-ExtraLightItalic.ttf" "ExtraLight Italic" ExtraLightItalic 200
                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-LightItalic.ttf" "Light Italic" LightItalic 300
                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-Italic.ttf" Italic Italic 400
                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-MediumItalic.ttf" "Medium Italic" MediumItalic 500
                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-SemiBoldItalic.ttf" "SemiBold Italic" SemiBoldItalic 600
                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-BoldItalic.ttf" "Bold Italic" BoldItalic 700
                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-ExtraBoldItalic.ttf" "ExtraBold Italic" ExtraBoldItalic 800
                            make_instance "$italic" "$out/share/fonts/truetype/InstrumentSans90-BlackItalic.ttf" "Black Italic" BlackItalic 900

                            runHook postInstall
            '';
          };
        uncut-sans = pkgs.stdenvNoCC.mkDerivation {
          pname = "uncut-sans-variable";
          version = "unstable-2024-09-24";
          src = inputs.uncut-sans;

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            install -Dm644 Variable/UncutSans-Variable.ttf \
              $out/share/fonts/truetype/UncutSans-Variable.ttf
            runHook postInstall
          '';
        };
      in
      [
        bluu-next
        google-fonts
        instrument-sans-90
        iosevka
        uncut-sans
      ]
      ++ (with pkgs; [
        junicode
        nacelle
        route159
      ]);
  };

  hardware = {
    bluetooth.enable = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = true;
      open = false; # true;
      package = kernelPackages.nvidiaPackages.latest;
      powerManagement = {
        enable = true;
        finegrained = true;
      };
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
    sane = {
      # printer scanners
      disabledDefaultBackends = [
        "escl"
        "v4l"
      ];
      enable = true;
      extraBackends = with pkgs; [ sane-airscan ];
    };
  };

  i18n.defaultLocale = "en_US.UTF-8";

  networking = {
    hostName = hostname;
    networkmanager =
      let
        inherit (config.age) secrets;
        secret-filenames = builtins.attrNames secrets;
        wifi-secret-filenames = builtins.filter (lib.strings.hasPrefix "wifi-") secret-filenames;
        wifi-secret-names = map (lib.strings.removePrefix "wifi-") wifi-secret-filenames;
      in
      {
        enable = true;
        ensureProfiles = {
          environmentFiles = map (name: config.age.secrets.${name}.path) wifi-secret-filenames;
          profiles = builtins.listToAttrs (
            map (name: {
              # inherit name;
              name = "\$${name}_ssid";
              value = {
                connection = {
                  id = "\$${name}_ssid";
                  permissions = "";
                  type = "wifi";
                };
                ipv4.method = "auto";
                ipv6 = {
                  addr-gen-mode = "stable-privacy";
                  method = "auto";
                };
                wifi = {
                  mode = "infrastructure";
                  ssid = "\$${name}_ssid";
                };
                wifi-security = {
                  key-mgmt = "wpa-psk";
                  psk = "\$${name}_psk";
                  psk-flags = 0;
                };
              };
            }) wifi-secret-names
          );
        };
        logLevel = "INFO"; # "TRACE";
      };
  };

  nix = {
    channel.enable = false;
    enable = true;
    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
      ];
      extra-substituters = [
        "https://cache.nixos-cuda.org"
        "https://cache.numtide.com"
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      http-connections = 0; # unlimited
      log-lines = 48;
      min-free = "32G";
      preallocate-contents = true;
      require-sigs = true;
      sandbox = false; # true;
      show-trace = true;
      stalled-download-timeout = 60; # seconds
      sync-before-registering = true;
      trusted-users = [ username ];
      use-xdg-base-directories = true;
      warn-large-path-threshold = "1G";

    };
  };

  nixpkgs = {
    config = {
      allowUnfreePredicate =
        pkg: builtins.any (regex: (builtins.match regex (lib.getName pkg)) != null) unfree-regex;
      cudaSupport = true;
      nvidia.acceptLicense = true;
    };
    # overlays = [ inputs.rust-overlay.overlays.default ];
  };

  programs =
    builtins.mapAttrs
      (_k: v: if v.dontEnable or false then removeAttrs v [ "dontEnable" ] else ({ enable = true; } // v))
      {
        bash = {
          dontEnable = true;
          completion.enable = true;
        };
        direnv = { };
        gamemode = { };
        git = {
          config = {
            commit.gpgsign = true;
            credential = {
              "https://gist.github.com" = {
                helper = "!gh auth git-credential";
                username = github-username;
              };
              "https://github.com" = {
                helper = "!gh auth git-credential";
                username = github-username;
              };
            };
            user = {
              email = "willstrgn@gmail.com";
              name = "Will Sturgeon";
            };
          };
          package = pkgs.gitFull;
        };
        gnupg = {
          dontEnable = true;
          agent = {
            enable = true;
            enableSSHSupport = true;
          };
        };
        hyprland = {
          package = with hyprPackages; hyprland;
          portalPackage = with hyprPackages; xdg-desktop-portal-hyprland;
          xwayland.enable = true;
        };
        nh.clean = {
          dates = "*-*-* 04:00:00";
          enable = true;
          extraArgs = nh-clean-all-flags;
        };
        nix-index = { };
        nixvim = {
          dependencies.lean.enable = lib.mkForce false;
          diagnostic.settings.virtual_text = true;
          extraConfigLua = ''
            local theme_path = vim.fn.expand('~/.local/state/caelestia/theme/nvim.lua')
            local last_theme_mtime = nil

            local function theme_mtime(path)
              local uv = vim.uv or vim.loop
              local stat = uv.fs_stat(path)
              if stat == nil then
                return nil
              end
              return stat.mtime.sec .. ':' .. stat.mtime.nsec
            end

            local function apply_dynamic_theme(force)
              local mtime = theme_mtime(theme_path)
              if not force and mtime == last_theme_mtime then
                return
              end

              last_theme_mtime = mtime
              local ok = false
              if mtime ~= nil then
                ok = pcall(dofile, theme_path)
              end
              if not ok then
                ${appTheme.editor.lua}
              end
            end

            apply_dynamic_theme(true)

            vim.api.nvim_create_autocmd("FocusGained", {
              callback = function()
                apply_dynamic_theme(false)
              end,
            })

            local timer = (vim.uv or vim.loop).new_timer()
            timer:start(60000, 60000, vim.schedule_wrap(function()
              apply_dynamic_theme(false)
            end))
          '';
          extraPlugins = lib.optional (appTheme.editor.package != null) appTheme.editor.package;
          opts = rec {
            autoread = true;
            background = appTheme.mode;
            backspace = [
              "eol"
              "indent"
              "start"
            ];
            belloff = "all";
            cursorcolumn = true;
            cursorline = true;
            cursorlineopt = "both";
            digraph = false;
            display = [ "uhex" ];
            endofline = true;
            errorbells = false;
            expandtab = true;
            fixendofline = true;
            foldenable = true;
            hlsearch = true;
            icon = true;
            ignorecase = true;
            incsearch = true;
            joinspaces = false;
            linebreak = false;
            list = true;
            modeline = false;
            mouse = "";
            mousehide = true;
            number = true;
            relativenumber = true;
            ruler = true;
            scrolloff = 8;
            shiftwidth = tabstop;
            sidescroll = scrolloff;
            sidescrolloff = scrolloff;
            smartcase = true;
            smarttab = true;
            softtabstop = tabstop;
            splitbelow = true;
            splitright = true;
            tabstop = 4;
            title = true;
            visualbell = false;
            wildmenu = true;
            wrap = false;
          };
          performance.byteCompileLua = {
            configs = true;
            enable = true;
            initLua = true;
            luaLib = true;
            nvimRuntime = true;
            plugins = true;
          };
          plugins = builtins.mapAttrs (_k: v: v // { enable = true; }) {
            cmp = {
              autoEnableSources = true;
              settings = {
                sources = [
                  { name = "nvim_lsp"; }
                  { name = "path"; }
                  { name = "buffer"; }
                ];
                mapping = {
                  "<C-Space>" = "cmp.mapping.complete()";
                  "<C-d>" = "cmp.mapping.scroll_docs(-4)";
                  "<C-e>" = "cmp.mapping.close()";
                  "<C-f>" = "cmp.mapping.scroll_docs(4)";
                  "<CR>" = "cmp.mapping.confirm({ select = true })";
                  "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
                  "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
                };
              };
            };
            gitsigns = { };
            lean.package = pkgs.vimPlugins.lean-nvim;
            lsp = {
              inlayHints = true;
              keymaps = {
                silent = true;
                diagnostic = {
                  # Navigate in diagnostics
                  "<leader>k" = "goto_prev";
                  "<leader>j" = "goto_next";
                };

                lspBuf = {
                  gd = "definition";
                  gD = "references";
                  gt = "type_definition";
                  gi = "implementation";
                  K = "hover";
                  "<F2>" = "rename";
                };
              };
              servers = builtins.mapAttrs (_k: v: { enable = true; } // v) {
                clangd = { };
                hls.installGhc = false;
                hyprls = { };
                lua_ls.settings.diagnostics.globals = [ "vim" ];
                nil_ls.config.nix.flake.autoArchive = false;
                nixd = { };
                ocamllsp.package = null;
                ruff = { };
                rust_analyzer = {
                  # cargoPackage = rust-toolchain;
                  installCargo = false;
                  installRustc = false;
                  # package = rust-toolchain;
                  settings = {
                    cargo = {
                      features = "all";
                      allTargets = true;
                      # loadOutDirsFromCheck = true;
                      # runBuildScripts = true;
                    };
                    check = {
                      features = "all";
                      allTargets = true;
                      command = "clippy";
                      extraArgs = [
                        "--"
                        "--no-deps"
                        # enable the kitchen sink:
                        "-Wclippy::cargo"
                        "-Wclippy::complexity"
                        "-Dclippy::correctness"
                        "-Wclippy::perf"
                        "-Wclippy::pedantic"
                        "-Wclippy::style"
                        "-Wclippy::suspicious"
                        # then disable selectively:
                        "-Aclippy::blanket-clippy-restriction-lints"
                        "-Aclippy::field-scoped-visibility-modifiers"
                        "-Aclippy::from-iter-instead-of-collect"
                        "-Aclippy::implicit-return"
                        "-Aclippy::inline-always"
                        "-Aclippy::map-err-ignore"
                        "-Aclippy::min-ident-chars"
                        "-Aclippy::mod-module-files"
                        "-Aclippy::needless-borrowed-reference"
                        "-Aclippy::pub-with-shorthand"
                        "-Aclippy::question-mark-used"
                        "-Aclippy::ref-patterns"
                        "-Aclippy::semicolon-if-nothing-returned"
                        "-Aclippy::semicolon-outside-block"
                        "-Aclippy::separated-literal-suffix"
                        "-Aclippy::shadow-reuse"
                        "-Aclippy::shadow-same"
                        "-Aclippy::shadow-unrelated"
                        "-Aclippy::single-char-lifetime-names"
                        "-Aclippy::type-complexity"
                        "-Aclippy::wildcard-enum-match-arm"
                      ];
                    };
                    checkOnSave = true;
                    procMacro.enable = true;
                  };
                };
                taplo = { };
              };
            };
            lsp-format.lspServersToEnable = "all";
            # lualine.settings.options.globalstatus = true;
            # From <https://github.com/GaetanLepage/nix-config/blob/81a6c06fa6fc04a0436a55be344609418f4c4fd9/modules/home/core/programs/neovim/_plugins/telescope.nix>:
            telescope = {

              keymaps = {
                # Find files using Telescope command-line sugar.
                "<leader>fb" = "buffers";
                "<leader>fd" = "lsp_definitions";
                "<leader>ff" = "git_files"; # "find_files";
                "<leader>fg" = "live_grep";
                "<leader>fh" = "help_tags";
                "<leader>fl" = "loogle";
                "<leader>fm" = "man_pages";
                "<leader>fo" = "oldfiles";
                "<leader>fr" = "lsp_references";

                # FZF like bindings
                "<C-p>" = "git_files";
                "<leader>p" = "oldfiles";
                "<C-f>" = "live_grep";
              };

              settings.defaults = {
                file_ignore_patterns = [
                  "^.direnv/"
                  "^.git/"
                  "^.mypy_cache/"
                  "^__pycache__/"
                  "^data/"
                  "^output/"
                  "^result/"
                  "^target/"
                  "%.lock"
                ];
                set_env.COLORTERM = "truecolor";
              };
            };
            treesitter.settings = {
              ensure_installed = "all";
              highlight.enable = true;
              ignore_install = [
                "ipkg"
                "norg"
              ];
              incremental_selection.enable = true;
              indent.enable = true;
            };
            web-devicons = { };
          };
          viAlias = true;
          vimAlias = true;
        };
        zsh = {
          enableBashCompletion = true;
          enableCompletion = true;
          interactiveShellInit = ''
            fortune | cowsay -r
            echo
          '';
          promptInit = ''
            case $(tty) in
              (/dev/tty*) :;;
              (*) source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme;;
            esac
          '';
        };
      };

  security = {
    polkit.enable = true;
    rtkit.enable = true;
  };

  # Graphics & desktop:
  services = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    asusd = { };
    automatic-timezoned = { };
    avahi = {
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
        userServices = true;
      };
    };
    libinput = {
      touchpad = {
        clickMethod = "clickfinger";
        disableWhileTyping = true;
        naturalScrolling = true;
        tapping = false;
      };
    };
    logind.settings.Login = {
      # HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };
    openssh = {
      openFirewall = true;
    };
    pipewire = {
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    printing.drivers = with pkgs; [ canon-cups-ufr2 ];
    supergfxd = { };
    udev.packages = with pkgs; [ sane-airscan ];
    udisks2 = { };
    upower = { };
    xserver = {
      enable = false;
      xkb = keyboard;
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 256 * 1024; # 1024=1GiB
    }
  ];

  system = { inherit stateVersion; };

  systemd = {
    services = {
      install-private-test-fonts = {
        description = "Install encrypted private test fonts.";
        path = with pkgs; [
          fontconfig
          gnutar
          gzip
        ];
        script = ''
          shopt -s nullglob
          set -euxo pipefail

          install_font_archive() {
            local secret_path="$1"
            local fonts_dir="$2"

            rm -rf "$fonts_dir"
            install -d -m0755 "$fonts_dir"
            tar -xzf "$secret_path" -C "$fonts_dir" --strip-components=1
            chmod -R u=rwX,go=rX "$fonts_dir"
            fc-cache -f "$fonts_dir"
          }

          install_font_archive ${config.age.secrets."absans.tar.gz".path} /var/lib/local-fonts/absans
          install_font_archive ${config.age.secrets."blanco.tar.gz".path} /var/lib/local-fonts/blanco
          install_font_archive ${config.age.secrets."foss-serif.tar.gz".path} /var/lib/local-fonts/foss-serif
          install_font_archive ${
            config.age.secrets."martina-plantijn.tar.gz".path
          } /var/lib/local-fonts/martina-plantijn
          install_font_archive ${config.age.secrets."signifier.tar.gz".path} /var/lib/local-fonts/signifier
          install_font_archive ${
            config.age.secrets."taurus-grotesk.tar.gz".path
          } /var/lib/local-fonts/taurus-grotesk
        '';
        serviceConfig = {
          RemainAfterExit = true;
          Type = "oneshot";
          User = "root";
        };
        wantedBy = [ "multi-user.target" ];
      };
      journal-gc = {
        path = with pkgs; [ systemd ];
        script = ''
          shopt -s nullglob
          set -euxo pipefail

          journalctl --vacuum-time=2d
        '';
        serviceConfig.User = "root";
        startAt = "*-*-* 04:00:00";
      };
      lake-gc = {
        script = ''
          shopt -s nullglob
          set -euxo pipefail

          find / -type d -name '\.lake' -exec rm -fr {} +
        '';
        serviceConfig.User = "root";
        startAt = "*-*-* 04:00:00";
      };
      logseq = {
        path = with pkgs; [ git ];
        script = ''
          shopt -s nullglob
          set -euxo pipefail

          cd ~/Logseq
          git add -A
          git commit --no-gpg-sign -m 'Automatic commit'
          git push
        '';
        serviceConfig.User = username;
        startAt = "minutely";
      };
      nix-index = {
        script = ''
          shopt -s nullglob
          set -euxo pipefail

          nix run nixpkgs#nix-index
        '';
        serviceConfig.User = username;
        startAt = "*-*-* 04:00:00";
      };
      nix-index-root = {
        script = ''
          shopt -s nullglob
          set -euxo pipefail

          nix run nixpkgs#nix-index
        '';
        serviceConfig.User = "root";
        startAt = "*-*-* 04:00:00";
      };
      nvidia-powerd = {
        after = [
          "systemd-modules-load.service"
          "nvidia-persistenced.service"
        ];
        requires = [ "nvidia-persistenced.service" ];
      };
      ${rebuild-nixos-service-name} = {
        path = with pkgs; [
          gh
          git
          gnupg
          nh
          nix
          nixos-rebuild
          openssh
          pmutils
          su
          systemd
        ];
        script = ''
          shopt -s nullglob
          set -euo pipefail

          export GH_TOKEN="$(cat ${config.age.secrets.gh-pat.path})"
          export GITHUB_TOKEN="$GH_TOKEN"
          export GIT_TERMINAL_PROMPT=0

          set -x

          if on_ac_power; then
              echo 'Computer is plugged in; continuing...'
          else
              echo 'Computer is not plugged in; aborting...'
              exit
          fi

          cd /etc/nixos
          nix flake update
          nix fmt

          nh os boot . ${nh-os-flags}

          git add -A
          git commit -m 'Automatic build succeeded' || :
          git push -u "https://github.com/${github-username}/nixos-configuration.git" main
          ${nrs}
        '';
        serviceConfig.User = "root";
        startAt = "hourly"; # "*-*-* 04:00:00";
      };
      supergfxd.path = [ pkgs.pciutils ];
    };

    user.services.aura-keyboard = {
      description = "Keyboard backlight on login.";
      script =
        # "asusctl aura effect static --colour ffffff";
        "asusctl aura effect rainbow-wave --direction right --speed low";
      wantedBy = [ "multi-user.target" ]; # starts after login
    };
    user.services = {
      night-shift = {
        environment = {
          CAELESTIA_SCHEME_NAME = desktopTheme.schemeName;
          CAELESTIA_SCHEME_FLAVOUR = desktopTheme.flavour;
          CAELESTIA_SCHEME_VARIANT = desktopTheme.caelestiaScheme.variant;
        };
        path = [
          (pkgs.python3.withPackages (pythonPackages: [ pythonPackages.astral ]))
          caelestiaCli
          hyprPackages.hyprland
        ];
        script = ''
          python ${./night-shift.py} \
            --latitude ${lib.escapeShellArg location.latitude} \
            --longitude ${lib.escapeShellArg location.longitude}
        '';
        startAt = "minutely";
      };
    };
  };

  users = {
    users.${username} = {
      inherit home;
      extraGroups = [
        "audio"
        "dialout" # USB
        "lp" # printing (& scanning?) documents
        "networkmanager"
        "scanner" # scanning documents
        "wheel" # `sudo`
      ];
      hashedPasswordFile = config.age.secrets.passwd.path;
      isNormalUser = true;
      shell = pkgs.zsh;
    };
  };
}
