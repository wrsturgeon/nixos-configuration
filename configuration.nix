{
  config,
  default-font,
  default-serif-font,
  default-monospace-font,
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
  llmAgentPackages = inputs.llm-agents.packages.${system};
  codexPackage = llmAgentPackages.codex;
  codexApplyPatch = pkgs.callPackage ./pi/safe-apply-patch/package.nix { codex = codexPackage; };
  piPackage = pkgs.callPackage ./pi/freeform-tools/package.nix { inherit (llmAgentPackages) pi; };
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
  terminalTheme = theme.defaultTerminalTheme;
  caelestiaCli =
    theme.patchCaelestiaCli
      inputs.caelestia-shell.inputs.caelestia-cli.packages.${system}.caelestia-cli;
  codexSettings = {
    approval_policy = "never"; # "on-request";
    features.hooks = true;
    model_reasoning_effort = "xhigh";
    model_reasoning_summary = "detailed";
    model_verbosity = "low";
    sandbox_mode = "danger-full-access"; # "workspace-write";
    sandbox_workspace_write = {
      exclude_slash_tmp = false;
      exclude_tmpdir_env_var = false;
      network_access = true;
      writable_roots = [
        "/home/${username}/.cache"
        "/home/${username}/.cargo"
        "/home/${username}/.local"
      ];
    };
    # service_tier = "fast";
    web_search = "live";
  };
  codexConfigToml =
    pkgs.runCommand "codex-system-config.toml"
      {
        nativeBuildInputs = [ pkgs.remarshal ];
        value = builtins.toJSON codexSettings;
        passAsFile = [ "value" ];
        preferLocalBuild = true;
      }
      ''
        json2toml "$valuePath" "$out"
        chmod 0644 "$out"
      '';

  rebuild-nixos-service-name = "rebuild-nixos";

  showerthoughtsFortunes = pkgs.stdenvNoCC.mkDerivation {
    name = "showerthoughts-fortunes-2016-12-01";
    src = pkgs.fetchurl {
      url = "https://skeeto.s3.amazonaws.com/share/showerthoughts";
      hash = "sha256-QdbdwcaecL1io3+Tq/Tc30CTY0AOsJv4nIavYApM78A=";
    };

    dontUnpack = true;
    nativeBuildInputs = [ pkgs.fortune ];

    installPhase = ''
      runHook preInstall

      install -Dm644 "$src" "$out/share/games/fortune/showerthoughts"
      strfile -s "$out/share/games/fortune/showerthoughts" "$out/share/games/fortune/showerthoughts.dat"

      runHook postInstall
    '';
  };

  fortuneWithShowerthoughts = pkgs.writeShellApplication {
    name = "fortune";
    text = ''
      set -euo pipefail

      use_fortune_mod=false
      args=()
      for arg in "$@"; do
        case "$arg" in
          (showerthoughts|showerthoughts-o)
            use_fortune_mod=true
            args+=("${showerthoughtsFortunes}/share/games/fortune/showerthoughts")
            ;;
          (*)
            args+=("$arg")
            ;;
        esac
      done

      if [ "$use_fortune_mod" = true ]; then
        exec ${pkgs.fortune}/bin/fortune "''${args[@]}"
      fi

      exec ${pkgs.bsdgames}/bin/fortune "''${args[@]}"
    '';
  };

  merriamWebsterWordOfTheDayOrFortune = pkgs.writeShellApplication {
    name = "mw-word-of-the-day-or-fortune";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      diffutils
      fortune
      python3
      util-linux
    ];
    text = ''
      set -euo pipefail

      format_message() {
        tr -d '\r' | expand -t 8 | fold -s -w 76
      }

      fallback() {
        fortune | format_message
      }

      show_showerthoughts() {
        fortune ${showerthoughtsFortunes}/share/games/fortune/showerthoughts | format_message
      }

      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        cache_base="$XDG_CACHE_HOME"
      elif [ -n "''${HOME:-}" ]; then
        cache_base="$HOME/.cache"
      else
        cache_base="/tmp"
      fi

      cache_dir="$cache_base/merriam-webster-word-of-the-day"
      latest="$cache_dir/latest.txt"
      history_dir="$cache_dir/history"
      history_index="$cache_dir/history-index"

      parse_word_of_the_day() {
        python3 ${./scripts/parse-merriam-webster-word-of-the-day.py} "$1"
      }

      remember_word() {
        python3 ${./scripts/remember-merriam-webster-word-of-the-day.py} "$1" "$history_dir" "$history_index"
      }

      refresh_cache() {
        exec 9>"$cache_dir/update.lock"
        flock -n 9 || exit 0

        tmp="$(mktemp "$cache_dir/wotd.XXXXXX")" || exit 0
        html_tmp="$(mktemp "$cache_dir/wotd.html.XXXXXX")" || {
          rm -f "$tmp"
          exit 0
        }
        trap 'rm -f "$tmp" "$html_tmp"' EXIT

        if curl \
          --compressed \
          --connect-timeout 2 \
          --fail \
          --location \
          --max-time 8 \
          --silent \
          --user-agent "nixos-mw-word-of-day/1.0" \
          --output "$html_tmp" \
          "https://www.merriam-webster.com/word-of-the-day" \
          && parse_word_of_the_day "$html_tmp" > "$tmp" \
          && [ -s "$tmp" ]; then
          mv -f "$tmp" "$latest"
          remember_word "$latest"
        fi
      }

      stage_refresh() {
        (refresh_cache) </dev/null >/dev/null 2>&1 &
      }

      show_history_word() {
        if [ ! -s "$history_index" ]; then
          return 1
        fi

        digest="$(shuf -n 1 "$history_index")" || return 1
        case "$digest" in
          (""|*[!0123456789abcdef]*) return 1 ;;
        esac
        [ "''${#digest}" -eq 64 ] || return 1

        cat "$history_dir/$digest.txt"
      }

      show_thirds_mix() {
        case "$(shuf -i 0-2 -n 1)" in
          (0) show_history_word || fallback ;;
          (1) show_showerthoughts || fallback ;;
          (2) fallback ;;
        esac
      }

      show_staged_or_fortune() (
        exec 8>"$cache_dir/display.lock"
        if ! flock -n 8; then
          fallback
          return 0
        fi

        if [ -s "$latest" ]; then
          remember_word "$latest" || true
        fi

        show_thirds_mix
      )

      if ! mkdir -p "$cache_dir"; then
        fallback
        exit 0
      fi

      show_staged_or_fortune
      stage_refresh
    '';
  };
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
    etc."codex/config.toml".source = codexConfigToml;
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
      ++ [
        (lib.hiPrio fortuneWithShowerthoughts)
        merriamWebsterWordOfTheDayOrFortune
      ]
      ++ (with pkgs; [
        asciiquarium
        binutils # ld, ar, objdump, etc.
        brightnessctl
        bsdgames
        btop
        bubblewrap
        cmatrix # for fun
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
        ripgrep
        sl
        tmux
        tree
        unzip
        usbutils
        valgrind
        wl-clipboard
        zip
      ])
      ++ (with stdenv; [ cc ])
      ++ (with pkgs.nvtopPackages; [ full ])
      ++ [
        codexApplyPatch
        codexPackage
        piPackage
      ];
    # usrbinenv = null; # https://github.com/NixOS/nix/issues/1205
    variables = {
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      EDITOR = "nvim";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      LIBVA_DRIVER_NAME = "nvidia";
      NIXOS_OZONE_WL = "1";
      NVD_BACKEND = "direct";
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
          default-serif-font
          "Source Serif 4"
        ];
        monospace = [ default-monospace-font ];
      };
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <dir>/var/lib/local-fonts/absans</dir>
          <dir>/var/lib/local-fonts/atlas</dir>
          <dir>/var/lib/local-fonts/blanco</dir>
          <dir>/var/lib/local-fonts/cabinet-grotesk</dir>
          <dir>/var/lib/local-fonts/foss-serif</dir>
          <dir>/var/lib/local-fonts/general-sans</dir>
          <dir>/var/lib/local-fonts/griffith-gothic-normal</dir>
          <dir>/var/lib/local-fonts/gt-america-90</dir>
          <dir>/var/lib/local-fonts/gt-america-95</dir>
          <dir>/var/lib/local-fonts/mallory-compact</dir>
          <dir>/var/lib/local-fonts/mallory-narrow</dir>
          <dir>/var/lib/local-fonts/mallory-normal</dir>
          <dir>/var/lib/local-fonts/marr-sans</dir>
          <dir>/var/lib/local-fonts/martina-plantijn</dir>
          <dir>/var/lib/local-fonts/neue-haas-grotesk</dir>
          <dir>/var/lib/local-fonts/seaford</dir>
          <dir>/var/lib/local-fonts/signifier</dir>
          <dir>/var/lib/local-fonts/switzer</dir>
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
        packageDesktopFonts =
          {
            pname,
            src,
            version,
          }:
          pkgs.stdenvNoCC.mkDerivation {
            inherit pname src version;

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall

              install -d $out/share/fonts/opentype $out/share/fonts/truetype

              find_desktop_fonts() {
                local extension="$1"
                find . -type f -iname "*.$extension" \
                  ! -ipath '*/webfont/*' \
                  ! -ipath '*/webfonts/*' \
                  ! -ipath '*/source/*' \
                  ! -ipath '*/sources/*' \
                  ! -ipath '*/documentation/*' \
                  ! -ipath '*/docs/*' \
                  | sort
              }

              install_fonts() {
                local dest="$1"
                shift

                local font base target
                for font in "$@"; do
                  base="$(basename "$font")"
                  target="$dest/$base"
                  if [[ -e "$target" ]]; then
                    echo "error: duplicate font filename: $base" >&2
                    exit 1
                  fi
                  install -m444 "$font" "$target"
                done
              }

              mapfile -t otf_fonts < <(find_desktop_fonts otf)
              mapfile -t all_ttf_fonts < <(find_desktop_fonts ttf)

              declare -A otf_stems=()
              for font in "''${otf_fonts[@]}"; do
                otf_stems["$(basename "''${font%.*}")"]=1
              done

              # Prefer OTF for duplicate static desktop fonts, but keep TTF-only
              # styles and variable TTFs.
              ttf_fonts=()
              for font in "''${all_ttf_fonts[@]}"; do
                stem="$(basename "''${font%.*}")"
                if [[ -n "''${otf_stems[$stem]:-}" ]]; then
                  continue
                fi
                ttf_fonts+=("$font")
              done

              if (( ''${#otf_fonts[@]} == 0 && ''${#ttf_fonts[@]} == 0 )); then
                echo "error: no desktop OTF/TTF fonts found in $src" >&2
                exit 1
              fi

              install_fonts $out/share/fonts/opentype "''${otf_fonts[@]}"
              install_fonts $out/share/fonts/truetype "''${ttf_fonts[@]}"

              runHook postInstall
            '';
          };
        aspekta = packageDesktopFonts {
          pname = "aspekta";
          version = "unstable-2025-02-11";
          src = inputs.aspekta;
        };
        bluu-next = packageDesktopFonts {
          pname = "bluu-next";
          version = "unstable-2019-07-04";
          src = inputs.bluu-next;
        };
        google-fonts = import ./google-fonts.nix { inherit inputs pkgs; };
        spline-sans-ss02 =
          let
            fonttools = pkgs.python3.withPackages (ps: [ ps.fonttools ]);
          in
          pkgs.stdenvNoCC.mkDerivation {
            pname = "spline-sans-ss02";
            version = "unstable-2026-03-13";
            src = google-fonts;

            dontUnpack = true;
            dontConfigure = true;
            dontBuild = true;

            nativeBuildInputs = [ fonttools ];

            installPhase = ''
              runHook preInstall

              install -d $out/share/fonts/truetype
              input="$src/share/fonts/truetype/SplineSans[wght].ttf"
              output="$out/share/fonts/truetype/SplineSansSS02[wght].ttf"
              install -m644 "$input" "$output"

              python ${./scripts/build-spline-sans-ss02.py} "$output"

              chmod 444 "$output"

              runHook postInstall
            '';
          };
        makeVariableFontVariant =
          {
            axisDefaultSources ? { },
            axisBoosts ? { },
            axisRanges ? { },
            faces,
            family,
            pname,
            psFamily ? builtins.replaceStrings [ " " ] [ "" ] family,
            src,
            version,
          }:
          let
            fonttools = pkgs.python3.withPackages (ps: [ ps.fonttools ]);
            variantConfig = builtins.toJSON {
              inherit
                axisDefaultSources
                axisBoosts
                axisRanges
                faces
                family
                psFamily
                ;
            };
          in
          pkgs.stdenvNoCC.mkDerivation {
            inherit pname src version;

            dontConfigure = true;
            dontBuild = true;

            nativeBuildInputs = [ fonttools ];

            installPhase = ''
              runHook preInstall

              install -d $out/share/fonts/truetype

              cp ${pkgs.writeText "variant-config.json" variantConfig} variant-config.json

              python ${./scripts/build-variable-font-variant.py}

              runHook postInstall
            '';
          };
        makeBricolageGrotesqueWidth =
          {
            display ? toString width,
            suffix ? builtins.replaceStrings [ "." ] [ "" ] display,
            width,
          }:
          makeVariableFontVariant {
            pname = "bricolage-grotesque-${display}";
            version = "unstable-2026-03-13";
            src = google-fonts;
            family = "Bricolage Grotesque ${display}";
            psFamily = "BricolageGrotesque${suffix}";
            axisDefaultSources.wdth = width;
            axisRanges = {
              opsz = {
                min = 12;
                default = 14;
                max = 96;
              };
              wght = {
                min = 200;
                default = 400;
                max = 800;
              };
            };
            faces = [
              {
                input = "share/fonts/truetype/BricolageGrotesque[opsz,wdth,wght].ttf";
                output = "BricolageGrotesque${suffix}[opsz,wdth,wght].ttf";
                style = "Regular";
              }
            ];
          };
        bricolage-grotesque-90 = makeBricolageGrotesqueWidth { width = 90; };
        bricolage-grotesque-92_5 = makeBricolageGrotesqueWidth {
          display = "92.5";
          suffix = "925";
          width = 92.5;
        };
        bricolage-grotesque-95 = makeBricolageGrotesqueWidth { width = 95; };
        instrument-sans-90 = makeVariableFontVariant {
          pname = "instrument-sans-90";
          version = "unstable-2026-03-13";
          src = google-fonts;
          family = "Instrument Sans 90";
          psFamily = "InstrumentSans90";
          axisDefaultSources.wdth = 90;
          axisRanges.wght = {
            min = 400;
            default = 425;
            max = 700;
          };
          axisBoosts.wght = 25;
          faces = [
            {
              input = "share/fonts/truetype/InstrumentSans[wdth,wght].ttf";
              output = "InstrumentSans90[wdth,wght].ttf";
              style = "Regular";
            }
            {
              input = "share/fonts/truetype/InstrumentSans-Italic[wdth,wght].ttf";
              output = "InstrumentSans90-Italic[wdth,wght].ttf";
              style = "Italic";
            }
          ];
        };
        uncut-sans = packageDesktopFonts {
          pname = "uncut-sans";
          version = "unstable-2024-09-24";
          src = inputs.uncut-sans;
        };
      in
      [
        aspekta
        bluu-next
        bricolage-grotesque-90
        bricolage-grotesque-92_5
        bricolage-grotesque-95
        google-fonts
        instrument-sans-90
        spline-sans-ss02
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
    firewall = {
      enable = true;
      logRefusedPackets = true;
    };
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
    nftables.enable = true;
  };

  nix = {
    channel.enable = false;
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
    enable = true;
    settings = {
      experimental-features = [
        "cgroups"
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
      sandbox = true;
      show-trace = true;
      stalled-download-timeout = 60; # seconds
      sync-before-registering = true;
      trusted-users = [ username ];
      use-xdg-base-directories = true;
      use-cgroups = true;
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
        dconf = { };
        direnv = { };
        fzf = {
          dontEnable = true;
          fuzzyCompletion = true;
          keybindings = true;
        };
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
                ${terminalTheme.editor.lua}
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
          extraPlugins = lib.optional (terminalTheme.editor.package != null) terminalTheme.editor.package;
          opts = rec {
            autoread = true;
            background = terminalTheme.mode;
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
            mw-word-of-the-day-or-fortune | cowsay -rn
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
    usbmuxd = { };
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
          findutils
          gnutar
          gzip
          rsync
          unzip
          util-linux
          (python3.withPackages (ps: [ ps.fonttools ]))
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

          install_font_file() {
            local secret_path="$1"
            local font_path="$2"
            local fonts_dir
            fonts_dir="$(dirname "$font_path")"

            rm -rf "$fonts_dir"
            install -d -m0755 "$fonts_dir"
            install -m0644 "$secret_path" "$font_path"
            fc-cache -f "$fonts_dir"
          }

          install_font_zip() {
            local secret_path="$1"
            local fonts_dir="$2"
            local base font installed target tmp

            tmp="$(mktemp -d)"
            rm -rf "$fonts_dir"
            install -d -m0755 "$fonts_dir"
            unzip -q "$secret_path" -d "$tmp"

            installed=0
            while IFS= read -r -d "" font; do
              base="$(basename "$font")"
              target="$fonts_dir/$base"
              if [ -e "$target" ]; then
                echo "error: duplicate font filename in $secret_path: $base" >&2
                exit 1
              fi

              install -m0644 "$font" "$target"
              installed=$((installed + 1))
            done < <(
              find "$tmp" \
                -type f \
                \( -iname '*.otf' -o -iname '*.ttf' \) \
                ! -path '*/__MACOSX/*' \
                ! -name '._*' \
                ! -ipath '*/web/*' \
                ! -ipath '*/webfont/*' \
                ! -ipath '*/webfonts/*' \
                ! -ipath '*/source/*' \
                ! -ipath '*/sources/*' \
                ! -ipath '*/documentation/*' \
                ! -ipath '*/docs/*' \
                -print0
            )

            if (( installed == 0 )); then
              echo "error: no desktop OTF/TTF fonts found in $secret_path" >&2
              exit 1
            fi

            chmod -R u=rwX,go=rX "$fonts_dir"
            fc-cache -f "$fonts_dir"
            rm -rf "$tmp"
          }

          install_gt_america_width() {
            local input="$1"
            local output="$2"
            local width="$3"
            local fonts_dir tmp prepared
            fonts_dir="$(dirname "$output")"
            tmp="$(mktemp -d)"
            prepared="$tmp/GT-America-Trial-VF.ttf"

            rm -rf "$fonts_dir"
            install -d -m0755 "$fonts_dir"
            cp "$input" "$prepared"

            python ${./scripts/build-gt-america-width.py} "$prepared" "$output" "$width"

            chmod 0644 "$output"
            fc-cache -f "$fonts_dir"
            rm -rf "$tmp"
          }

          mirror_local_fonts_for_user() {
            local local_fonts_root="/var/lib/local-fonts"
            local user_fonts_root=${lib.escapeShellArg "${home}/.local/share/fonts"}
            local user_local_fonts_dir="$user_fonts_root/local-fonts"
            local font_user=${lib.escapeShellArg username}
            local font_home=${lib.escapeShellArg home}

            install -d -m0755 -o "$font_user" "$user_fonts_root"
            rm -rf "$user_local_fonts_dir"
            install -d -m0755 -o "$font_user" "$user_local_fonts_dir"

            rsync -a --delete "$local_fonts_root"/ "$user_local_fonts_dir"/
            chown -R "$font_user:" "$user_local_fonts_dir"
            chmod -R u=rwX,go=rX "$user_local_fonts_dir"
            runuser -u "$font_user" -- env HOME="$font_home" fc-cache -f "$user_local_fonts_dir"
          }

          install_font_archive ${config.age.secrets."absans.tar.gz".path} /var/lib/local-fonts/absans
          install_font_zip ${config.age.secrets."Atlas_Collection.zip".path} /var/lib/local-fonts/atlas
          install_font_archive ${config.age.secrets."blanco.tar.gz".path} /var/lib/local-fonts/blanco
          install_font_zip ${
            config.age.secrets."CabinetGrotesk_Complete.zip".path
          } /var/lib/local-fonts/cabinet-grotesk
          install_font_archive ${config.age.secrets."foss-serif.tar.gz".path} /var/lib/local-fonts/foss-serif
          install_font_zip ${
            config.age.secrets."GeneralSans_Complete.zip".path
          } /var/lib/local-fonts/general-sans
          install_font_zip ${
            config.age.secrets."griffith-gothic-normal-trial-otf.zip".path
          } /var/lib/local-fonts/griffith-gothic-normal
          install_font_file ${config.age.secrets."gt-america-trial-vf.ttf".path} \
            /var/lib/local-fonts/gt-america-trial-vf/GT-America-Trial-VF.ttf
          install_gt_america_width \
            /var/lib/local-fonts/gt-america-trial-vf/GT-America-Trial-VF.ttf \
            '/var/lib/local-fonts/gt-america-90/GT-America-90[wdth,wght].ttf' \
            90
          install_gt_america_width \
            /var/lib/local-fonts/gt-america-trial-vf/GT-America-Trial-VF.ttf \
            '/var/lib/local-fonts/gt-america-95/GT-America-95[wdth,wght].ttf' \
            95
          install_font_zip ${
            config.age.secrets."mallory-trial-compact-otf.zip".path
          } /var/lib/local-fonts/mallory-compact
          install_font_zip ${
            config.age.secrets."mallory-trial-narrow-otf.zip".path
          } /var/lib/local-fonts/mallory-narrow
          install_font_zip ${
            config.age.secrets."mallory-trial-normal-otf.zip".path
          } /var/lib/local-fonts/mallory-normal
          install_font_archive ${
            config.age.secrets."martina-plantijn.tar.gz".path
          } /var/lib/local-fonts/martina-plantijn
          install_font_zip ${
            config.age.secrets."Marr_Sans_Collection.zip".path
          } /var/lib/local-fonts/marr-sans
          install_font_zip ${
            config.age.secrets."Neue_Haas_Grotesk_Collection.zip".path
          } /var/lib/local-fonts/neue-haas-grotesk
          install_font_zip ${config.age.secrets."seaford-trial-otf.zip".path} /var/lib/local-fonts/seaford
          install_font_archive ${config.age.secrets."signifier.tar.gz".path} /var/lib/local-fonts/signifier
          install_font_zip ${config.age.secrets."Switzer_Complete.zip".path} /var/lib/local-fonts/switzer
          install_font_archive ${
            config.age.secrets."taurus-grotesk.tar.gz".path
          } /var/lib/local-fonts/taurus-grotesk

          mirror_local_fonts_for_user
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
      build-artifact-gc = {
        path = with pkgs; [
          coreutils
          findutils
        ];
        script = ''
          shopt -s nullglob
          set -euxo pipefail

          roots=(
            /home/${username}/Desktop/Code
            /home/${username}/pbt
          )

          existing_roots=()
          for root in "''${roots[@]}"; do
            if [ -e "$root" ]; then
              existing_roots+=("$root")
            fi
          done

          if [ "''${#existing_roots[@]}" -eq 0 ]; then
            exit 0
          fi

          find "''${existing_roots[@]}" -xdev -mindepth 1 \
            \( -path /home/${username}/.cache -o -path /home/${username}/.local/share/Trash -o -path /root/.cache \) -prune -o \
            \( -type d \( -name target -o -name _build -o -name .lake -o -name .direnv \) -prune -print -exec rm -rf -- {} + \) -o \
            \( -type f -name 'vgcore.*' -print -exec rm -f -- {} + \)
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
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
        restartIfChanged = false;
        stopIfChanged = false;

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

          nh os boot . ${nh-os-flags} --cores=1 # --max-jobs=1

          git add -A
          git commit -m 'Automatic build succeeded' || :
          git push -u "https://github.com/${github-username}/nixos-configuration.git" main
          ${nrs}
        '';
        serviceConfig = {
          User = "root";

          Nice = 19;
          CPUSchedulingPolicy = "idle";
          IOSchedulingClass = "idle";

          CPUWeight = "idle";
          IOWeight = 1;

          MemoryHigh = "50%";
          MemoryMax = "75%";

          OOMPolicy = "stop";
        };
        startAt = "hourly"; # "*-*-* 04:00:00";
      };
      supergfxd.path = [ pkgs.pciutils ];
    };

    slices.user.sliceConfig.MemoryLow = "25%";

    timers.build-artifact-gc.timerConfig.Persistent = true;

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
          pkgs.brightnessctl
          pkgs.dconf
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
