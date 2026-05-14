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

                            cat > variant-config.json <<'JSON'
              ${variantConfig}
              JSON

                            python <<'PY'
              from fontTools.ttLib import TTFont
              import json
              import os
              import shutil
              import subprocess
              import tempfile


              def clamp(value, minimum, maximum):
                  return max(minimum, min(maximum, value))


              def fmt_axis_value(value):
                  value = float(value)
                  return str(int(value)) if value.is_integer() else str(value)


              def get_axis(font, tag):
                  if "fvar" not in font:
                      raise ValueError(f"font has no fvar table; cannot set {tag!r} default source")

                  for axis in font["fvar"].axes:
                      if axis.axisTag == tag:
                          return axis

                  raise ValueError(f"font has no {tag!r} axis")


              def build_axis_args(font, axis_default_sources, axis_ranges):
                  overlap = set(axis_default_sources) & set(axis_ranges)
                  if overlap:
                      axes = ", ".join(sorted(overlap))
                      raise ValueError(f"axis listed in both axisDefaultSources and axisRanges: {axes}")

                  axis_args = []
                  axis_default_boosts = {}
                  for tag, value in axis_default_sources.items():
                      axis = get_axis(font, tag)
                      value = float(value)
                      minimum = float(axis.minValue)
                      default = float(axis.defaultValue)
                      maximum = float(axis.maxValue)
                      if value < minimum or value > maximum:
                          raise ValueError(
                              f"{tag!r} default source {fmt_axis_value(value)} "
                              f"is outside {fmt_axis_value(minimum)}:{fmt_axis_value(maximum)}"
                          )

                      axis_args.append(
                          f"{tag}={fmt_axis_value(minimum)}:{fmt_axis_value(value)}:{fmt_axis_value(maximum)}"
                      )
                      if value != default:
                          axis_default_boosts[tag] = value - default

                  axis_args += [
                      f"{tag}={fmt_axis_value(values['min'])}:{fmt_axis_value(values['default'])}:{fmt_axis_value(values['max'])}"
                      for tag, values in axis_ranges.items()
                  ]

                  return axis_args, axis_default_boosts


              def apply_axis_boosts(font, axis_boosts):
                  if not axis_boosts or "fvar" not in font:
                      return {}

                  boosted_bounds = {}
                  for axis in font["fvar"].axes:
                      boost = axis_boosts.get(axis.axisTag)
                      if boost is None:
                          continue

                      boost = float(boost)
                      axis.minValue -= boost
                      axis.defaultValue -= boost
                      axis.maxValue -= boost
                      boosted_bounds[axis.axisTag] = (axis.minValue, axis.maxValue, axis.defaultValue)

                  for instance in font["fvar"].instances:
                      for tag, (minimum, maximum, _default) in boosted_bounds.items():
                          if tag in instance.coordinates:
                              instance.coordinates[tag] = clamp(float(instance.coordinates[tag]), minimum, maximum)

                  if "wght" in boosted_bounds and "OS/2" in font:
                      font["OS/2"].usWeightClass = round(boosted_bounds["wght"][2])

                  return boosted_bounds


              def clamp_stat_axis_values(font, axis_bounds):
                  if not axis_bounds or "STAT" not in font:
                      return

                  stat = font["STAT"].table
                  design_axes = getattr(getattr(stat, "DesignAxisRecord", None), "Axis", None)
                  axis_values = getattr(getattr(stat, "AxisValueArray", None), "AxisValue", None)
                  if not design_axes or not axis_values:
                      return

                  axis_tags = {index: axis.AxisTag for index, axis in enumerate(design_axes)}

                  def adjust(axis_index, value):
                      tag = axis_tags.get(axis_index)
                      if tag not in axis_bounds:
                          return value
                      minimum, maximum, _default = axis_bounds[tag]
                      return clamp(float(value), minimum, maximum)

                  for axis_value in axis_values:
                      fmt = axis_value.Format
                      if fmt in (1, 3):
                          axis_value.Value = adjust(axis_value.AxisIndex, axis_value.Value)
                          if fmt == 3:
                              axis_value.LinkedValue = adjust(axis_value.AxisIndex, axis_value.LinkedValue)
                      elif fmt == 2:
                          axis_value.NominalValue = adjust(axis_value.AxisIndex, axis_value.NominalValue)
                          axis_value.RangeMinValue = adjust(axis_value.AxisIndex, axis_value.RangeMinValue)
                          axis_value.RangeMaxValue = adjust(axis_value.AxisIndex, axis_value.RangeMaxValue)
                      elif fmt == 4:
                          for record in axis_value.AxisValueRecord:
                              record.Value = adjust(record.AxisIndex, record.Value)


              def rename_font(font, family, ps_family, style, ps_suffix):
                  ps_suffix = ps_suffix if ps_suffix is not None else "".join(style.split())
                  full_name = family if style == "Regular" else f"{family} {style}"
                  postscript_name = ps_family if style == "Regular" else f"{ps_family}-{ps_suffix}"
                  values = {
                      1: family,
                      2: style,
                      3: f"generated;{postscript_name}",
                      4: full_name,
                      6: postscript_name,
                      16: family,
                      17: style,
                      25: ps_family,
                  }

                  for record in font["name"].names:
                      value = values.get(record.nameID)
                      if value is None:
                          continue
                      record.string = value.encode(record.getEncoding(), errors="replace")


              def main():
                  with open("variant-config.json") as f:
                      config = json.load(f)

                  source_root = os.environ["src"]
                  output_root = os.path.join(os.environ["out"], "share/fonts/truetype")
                  family = config["family"]
                  ps_family = config["psFamily"]
                  axis_default_sources = config.get("axisDefaultSources", {})
                  axis_ranges = config.get("axisRanges", {})
                  axis_boosts = config.get("axisBoosts", {})

                  boost_overlap = set(axis_default_sources) & set(axis_boosts)
                  if boost_overlap:
                      axes = ", ".join(sorted(boost_overlap))
                      raise ValueError(f"axis listed in both axisDefaultSources and axisBoosts: {axes}")

                  for face in config["faces"]:
                      input_path = os.path.join(source_root, face["input"])
                      output_path = os.path.join(output_root, face["output"])

                      with tempfile.TemporaryDirectory() as temp_dir:
                          prepared_input = os.path.join(temp_dir, os.path.basename(face["input"]))
                          shutil.copyfile(input_path, prepared_input)
                          source_font = TTFont(prepared_input)
                          face_axis_args, axis_default_boosts = build_axis_args(
                              source_font,
                              axis_default_sources,
                              axis_ranges,
                          )
                          source_font.close()

                          subprocess.run(
                              [
                                  "fonttools",
                                  "varLib.instancer",
                                  prepared_input,
                                  *face_axis_args,
                                  "--output",
                                  output_path,
                              ],
                              check=True,
                          )

                      font = TTFont(output_path)
                      merged_axis_boosts = dict(axis_boosts)
                      merged_axis_boosts.update(axis_default_boosts)
                      boosted_bounds = apply_axis_boosts(font, merged_axis_boosts)
                      clamp_stat_axis_values(font, boosted_bounds)
                      rename_font(
                          font,
                          family,
                          ps_family,
                          face.get("style", "Regular"),
                          face.get("psSuffix"),
                      )
                      font.save(output_path)


              if __name__ == "__main__":
                  main()
              PY

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

                      python - "$prepared" "$output" "$width" <<'PY'
          from fontTools.ttLib import TTFont
          import subprocess
          import sys

          source_path = sys.argv[1]
          output_path = sys.argv[2]
          width_label = sys.argv[3]
          target_default = float(width_label)
          family = f"GT America {width_label}"
          ps_family = "GTAmerica" + width_label.replace(".", "")
          replacements = {
              "GT America Trial VF": family,
              "GTAmericaTrialVF": ps_family,
          }
          values = {
              1: family,
              2: "Regular",
              3: f"generated;{ps_family}",
              4: family,
              6: ps_family,
              16: family,
              17: "Regular",
              25: ps_family,
          }


          def clamp(value, minimum, maximum):
              return max(minimum, min(maximum, value))


          def fmt_axis_value(value):
              value = float(value)
              return str(int(value)) if value.is_integer() else str(value)


          def get_axis(font, tag):
              for axis in font["fvar"].axes:
                  if axis.axisTag == tag:
                      return axis
              raise ValueError(f"font has no {tag!r} axis")


          def apply_axis_boost(font, tag, boost):
              axis_bounds = {}
              for axis in font["fvar"].axes:
                  if axis.axisTag != tag:
                      continue

                  axis.minValue -= boost
                  axis.defaultValue -= boost
                  axis.maxValue -= boost
                  axis_bounds[tag] = (axis.minValue, axis.maxValue, axis.defaultValue)
                  break

              if tag not in axis_bounds:
                  raise ValueError(f"font has no {tag!r} axis")

              for instance in font["fvar"].instances:
                  if tag in instance.coordinates:
                      minimum, maximum, _default = axis_bounds[tag]
                      instance.coordinates[tag] = clamp(float(instance.coordinates[tag]), minimum, maximum)

              return axis_bounds


          def clamp_stat_axis_values(font, axis_bounds):
              if not axis_bounds or "STAT" not in font:
                  return

              stat = font["STAT"].table
              design_axes = getattr(getattr(stat, "DesignAxisRecord", None), "Axis", None)
              axis_values = getattr(getattr(stat, "AxisValueArray", None), "AxisValue", None)
              if not design_axes or not axis_values:
                  return

              axis_tags = {index: axis.AxisTag for index, axis in enumerate(design_axes)}

              def adjust(axis_index, value):
                  tag = axis_tags.get(axis_index)
                  if tag not in axis_bounds:
                      return value
                  minimum, maximum, _default = axis_bounds[tag]
                  return clamp(float(value), minimum, maximum)

              for axis_value in axis_values:
                  fmt = axis_value.Format
                  if fmt in (1, 3):
                      axis_value.Value = adjust(axis_value.AxisIndex, axis_value.Value)
                      if fmt == 3:
                          axis_value.LinkedValue = adjust(axis_value.AxisIndex, axis_value.LinkedValue)
                  elif fmt == 2:
                      axis_value.NominalValue = adjust(axis_value.AxisIndex, axis_value.NominalValue)
                      axis_value.RangeMinValue = adjust(axis_value.AxisIndex, axis_value.RangeMinValue)
                      axis_value.RangeMaxValue = adjust(axis_value.AxisIndex, axis_value.RangeMaxValue)
                  elif fmt == 4:
                      for record in axis_value.AxisValueRecord:
                          record.Value = adjust(record.AxisIndex, record.Value)


          source_font = TTFont(source_path)
          wdth = get_axis(source_font, "wdth")
          if target_default < wdth.minValue or target_default > wdth.maxValue:
              raise ValueError(
                  f"wdth default source {fmt_axis_value(target_default)} "
                  f"is outside {fmt_axis_value(wdth.minValue)}:{fmt_axis_value(wdth.maxValue)}"
              )
          wdth_arg = (
              f"wdth={fmt_axis_value(wdth.minValue)}:"
              f"{fmt_axis_value(target_default)}:"
              f"{fmt_axis_value(wdth.maxValue)}"
          )
          wdth_boost = target_default - float(wdth.defaultValue)
          source_font.close()

          subprocess.run(
              ["fonttools", "varLib.instancer", source_path, wdth_arg, "--output", output_path],
              check=True,
          )

          font = TTFont(output_path)
          boosted_bounds = apply_axis_boost(font, "wdth", wdth_boost)
          clamp_stat_axis_values(font, boosted_bounds)
          for record in font["name"].names:
              value = values.get(record.nameID)
              if value is None:
                  value = record.toUnicode()
                  for old, new in replacements.items():
                      value = value.replace(old, new)
              record.string = value.encode(record.getEncoding(), errors="replace")
          font.save(output_path)
          PY

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

                    install_font_archive ${
                      config.age.secrets."absans.tar.gz".path
                    } /var/lib/local-fonts/absans
                    install_font_zip ${
                      config.age.secrets."Atlas_Collection.zip".path
                    } /var/lib/local-fonts/atlas
                    install_font_archive ${
                      config.age.secrets."blanco.tar.gz".path
                    } /var/lib/local-fonts/blanco
                    install_font_zip ${
                      config.age.secrets."CabinetGrotesk_Complete.zip".path
                    } /var/lib/local-fonts/cabinet-grotesk
                    install_font_archive ${
                      config.age.secrets."foss-serif.tar.gz".path
                    } /var/lib/local-fonts/foss-serif
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
                    install_font_zip ${
                      config.age.secrets."seaford-trial-otf.zip".path
                    } /var/lib/local-fonts/seaford
                    install_font_archive ${
                      config.age.secrets."signifier.tar.gz".path
                    } /var/lib/local-fonts/signifier
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
