{
  config,
  inputs,
  lib,
  ...
}:

let
  flakeConfig = config;
  inherit (flakeConfig.local)
    github-username
    keyboard
    nh-clean-all-flags
    stateVersion
    ;
in
{
  options.local.nixos.modules.host = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = "Merged NixOS module for the configured host.";
  };

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

      kernelPackages = pkgs.linuxPackages_latest;
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
          EDITOR = "nvim";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          NIXOS_OZONE_WL = "1";
          NVD_BACKEND = "direct";
          OPENCODE_EXPERIMENTAL = "true";
          OPENSSL_DIR = "${pkgs.openssl}";
          XKB_DEFAULT_LAYOUT = keyboard.layout;
          XKB_DEFAULT_VARIANT = keyboard.variant;
        };
      };

      i18n.defaultLocale = "en_US.UTF-8";

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
            hyprland = { };
            nh.clean = {
              dates = "*-*-* 04:00:00";
              enable = true;
              extraArgs = nh-clean-all-flags;
            };
            nix-index = { };
            zsh = {
              enableBashCompletion = true;
              enableCompletion = true;
              interactiveShellInit = ''
                fortune | cowsay -rn
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

      swapDevices = [
        {
          device = "/swapfile";
          size = 256 * 1024; # 1024=1GiB
        }
      ];

      system = { inherit stateVersion; };

    };
}
