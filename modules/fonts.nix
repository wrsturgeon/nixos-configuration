{ config, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local)
    default-font
    default-monospace-font
    default-serif-font
    home
    username
    ;
in
{
  config.local.nixos.modules.host =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
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
            google-fonts = flakeConfig.local.mkGoogleFonts pkgs;
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

                  python ${../scripts/build-spline-sans-ss02.py} "$output"

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

                  python ${../scripts/build-variable-font-variant.py}

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
          in
          [
            bricolage-grotesque-90
            bricolage-grotesque-92_5
            bricolage-grotesque-95
            google-fonts
            instrument-sans-90
            spline-sans-ss02
            iosevka
          ]
          ++ (with pkgs; [
            junicode
            nacelle
            route159
          ])
          ++ (with pkgs.nerd-fonts; [ symbols-only ]);
      };

      systemd.services = {
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

                python ${../scripts/build-gt-america-width.py} "$prepared" "$output" "$width"

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
      };
    };
}
