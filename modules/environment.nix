{ config, inputs, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local) keyboard;
in
{
  config.local.nixos.modules.host =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (pkgs) stdenv;
      inherit (stdenv.targetPlatform) system;

      llmAgentPackages = inputs.llm-agents.packages.${system};
      upstreamCodexApplyPatch = llmAgentPackages.codex.overrideAttrs (oldAttrs: {
        pname = "codex-apply-patch";
        cargoBuildFlags = [
          "--package"
          "codex-apply-patch"
        ];
        doInstallCheck = false;
        env = builtins.removeAttrs (oldAttrs.env or { }) [ "RUSTY_V8_ARCHIVE" ];
        meta = (oldAttrs.meta or { }) // {
          description = "OpenAI Codex apply_patch tool";
          mainProgram = "apply_patch";
        };
        nativeInstallCheckInputs = [ ];
        postFixup = "";
        postInstall = "";
      });
      safeApplyPatch = pkgs.callPackage ../pi/safe-apply-patch/package.pkg.nix {
        applyPatch = upstreamCodexApplyPatch;
      };
      piPackage = pkgs.callPackage ../pi/freeform-tools/package.pkg.nix {
        inherit (llmAgentPackages) pi;
      };
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

      fortuneWithShowerthoughts = lib.hiPrio (
        pkgs.writeShellApplication {
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
        }
      );
    in
    {
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
          ct = "cargo nextest run --no-fail-fast";
          nb = "nix build -L";
          nf = "nix fmt";
          nr = "nix run -L";
          nrl = "nix run -L --no-substitute --no-use-registries"; # for "[n]ix [r]un [l]ocal"
          nrs = "systemctl start ${lib.strings.escapeShellArg rebuild-nixos-service-name} && journalctl -f -u ${lib.strings.escapeShellArg rebuild-nixos-service-name}"; # for "[n]ixos-[r]ebuild [s]witch"
        };
        systemPackages =
          (map (flake: flake.packages.${system}.default) (with inputs; [ agenix ]))
          ++ [
            fortuneWithShowerthoughts
            piPackage
            safeApplyPatch
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
            fd
            gh
            gnumake
            hunspell
            hunspellDicts.en_US
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
          ++ (with pkgs.nvtopPackages; [ full ]);
        # usrbinenv = null; # https://github.com/NixOS/nix/issues/1205
        variables = {
          AQ_DRM_DEVICES = "/dev/dri/card1";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          NIXOS_OZONE_WL = "1";
          NVD_BACKEND = "direct";
          OPENCODE_EXPERIMENTAL = "true";
          OPENSSL_DIR = "${pkgs.openssl}";
          XKB_DEFAULT_LAYOUT = keyboard.layout;
          XKB_DEFAULT_VARIANT = keyboard.variant;
        };
      };

    };
}
