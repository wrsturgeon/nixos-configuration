{
  build-users-group,
  config,
  home,
  hostname,
  inputs,
  keyboard,
  lib,
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
  hyprPackages = inputs.hyprland.packages.${system};

  rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
in
{
  age.secrets = builtins.mapAttrs (_: file: { inherit file; }) (
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
    shellAliases = {
      clippy = "cargo fmt && cargo clippy --all-features --all-targets --color=always 2>&1 | head -n 48";
      miri = "MIRIFLAGS='-Zmiri-env-forward=RUST_BACKTRACE' RUST_BACKTRACE=1 cargo miri test --all-features";
      nrs = "sudo ${nrs}";
    };
    systemPackages = [
      rust-toolchain
    ]
    ++ (map (flake: flake.packages.${system}.default) (
      with inputs;
      [
        agenix
        # quickshell # BUILD WITH OVERRIDES: https://github.com/caelestia-dots/shell/blob/main/flake.nix
      ]
    ))
    ++ (with pkgs; [
      binutils # ld, ar, objdump, etc.
      brightnessctl
      coreutils-full # ls, cp, pwd, etc.
      egl-wayland # NVIDIA (https://wiki.hypr.land/Nvidia/)
      gnumake
      hyprlauncher
      hyprpolkitagent
      jq # JSON utils
      killall
      mako
      nemo
      net-tools # ifconfig, etc.
      nixfmt
      openssl
      pkg-config
      playerctl
      ripgrep # rg
      spotifyd
      tmux
      tree
      wl-clipboard
    ])
    ++ (with stdenv; [ cc ]);
    # usrbinenv = null; # https://github.com/NixOS/nix/issues/1205
    variables = {
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      EDITOR = "nvim";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      LIBVA_DRIVER_NAME = "nvidia";
      NIXOS_OZONE_WL = "1";
      NVD_BACKEND = "direct";
      OPENSSL_DIR = "${pkgs.openssl}";
      XKB_DEFAULT_LAYOUT = keyboard.layout;
      XKB_DEFAULT_VARIANT = keyboard.variant;
    };
  };

  fonts.packages =
    let
      # with-src = pkgs.iosevka.overrideAttrs (
      #   final: _prev: rec {
      #     src = inputs.iosevka;
      #     npmDeps = pkgs.fetchNpmDeps {
      #       inherit src;
      #       hash = final.npmDepsHash;
      #     };
      #   }
      # );
      with-src = pkgs.iosevka;
      iosevka = with-src.override {
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
      # google-fonts =
      #   # pkgs.google-fonts.overrideAttrs { src = inputs.google-fonts; }
      #   stdenvNoCC.mkDerivation {
      #     pname = "google-fonts";
      #     version = "git";
      #     src = inputs.google-fonts;
      #     dontBuild = true;
      #     installPhase = ''
      #       find . -name '*.ttf' -exec install -m 444 -Dt $out/share/fonts/truetype '{}' +
      #       find . -name '*.otf' -exec install -m 444 -Dt $out/share/fonts/opentype '{}' +
      #     '';
      #   };
    in
    [
      iosevka
      # google-fonts
    ]
    ++ (with pkgs; [
      inter
      source-serif
    ]);

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
      package = kernelPackages.nvidiaPackages.beta;
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
        secret-names = builtins.attrNames secrets;
        wifi-secret-names = builtins.filter (lib.strings.hasPrefix "wifi-") secret-names;
      in
      {
        enable = true;
        ensureProfiles = {
          environmentFiles = map (name: config.age.secrets.${name}.path) wifi-secret-names;
          profiles = builtins.listToAttrs (
            map (
              wifi-hyphen-name:
              let
                name = lib.strings.removePrefix "wifi-" wifi-hyphen-name;
              in
              {
                inherit name;
                value = {
                  connection = {
                    id = name;
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
              }
            ) wifi-secret-names
          );
        };
      };
  };

  nix = {
    channel.enable = false;
    enable = true;
    settings = {
      inherit build-users-group;
      experimental-features = [
        "cgroups"
        "flakes"
        "nix-command"
      ];
      http-connections = 0; # unlimited
      log-lines = 48;
      min-free = "32G";
      preallocate-contents = true;
      # pure-eval = true; # seems to break `agenix`
      require-sigs = true;
      sandbox = true;
      sandbox-dev-shm-size = "10%";
      sandbox-fallback = false;
      show-trace = true;
      stalled-download-timeout = 60; # seconds
      sync-before-registering = true;
      # systemFeatures = [ "recursive-nix" ];
      use-cgroups = true;
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
    overlays = [ inputs.rust-overlay.overlays.default ];
  };

  programs = {
    bash.completion.enable = true;
    direnv.enable = true;
    gamemode.enable = true;
    git = {
      enable = true;
      config = {
        commit.gpgsign = true;
        user = {
          email = "willstrgn@gmail.com";
          name = "Will Sturgeon";
        };
      };
    };
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    hyprland = {
      enable = true;
      package = with hyprPackages; hyprland;
      portalPackage = with hyprPackages; xdg-desktop-portal-hyprland;
      xwayland.enable = false;
    };
    hyprlock.enable = true;
    nh = {
      clean = {
        dates = "daily";
        enable = true;
        extraArgs = nh-clean-all-flags;
      };
      enable = true;
    };
    nixvim = {
      colorschemes.ayu.enable = true;
      diagnostic.settings.virtual_text = true;
      enable = true;
      opts = rec {
        autoread = true;
        background = "dark";
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
              cargoPackage = rust-toolchain;
              installCargo = false;
              installRustc = false;
              package = rust-toolchain;
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
                    # and now disable selectively:
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
        lualine.settings.options.globalstatus = true;
        # From <https://github.com/GaetanLepage/nix-config/blob/81a6c06fa6fc04a0436a55be344609418f4c4fd9/modules/home/core/programs/neovim/_plugins/telescope.nix>:
        telescope = {

          keymaps = {
            # Find files using Telescope command-line sugar.
            "<leader>ff" = "find_files";
            "<leader>fg" = "live_grep";
            "<leader>b" = "buffers";
            "<leader>fh" = "help_tags";
            "<leader>fd" = "diagnostics";

            # FZF like bindings
            "<C-p>" = "git_files";
            "<leader>p" = "oldfiles";
            "<C-f>" = "live_grep";
          };

          settings.defaults = {
            file_ignore_patterns = [
              "^.git/"
              "^.mypy_cache/"
              "^__pycache__/"
              "^output/"
              "^data/"
              "%.ipynb"
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
      enable = true;
      promptInit = ''
        fortune | cowsay -r
        echo
        case $(tty) in
          (/dev/tty*) :;;
          (*) source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme;;
        esac
      '';
    };
  };

  security = {
    pam.services.hyprlock = { };
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
    hypridle = { };
    libinput = {
      touchpad = {
        clickMethod = "clickfinger";
        disableWhileTyping = true;
        naturalScrolling = true;
        tapping = false;
      };
    };
    openssh = { };
    pipewire = {
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
    printing.drivers = with pkgs; [ canon-cups-ufr2 ];
    spotifyd = { };
    supergfxd = { };
    udev.packages = with pkgs; [ sane-airscan ];
    udisks2 = { };
    xserver = {
      enable = false;
      xkb = keyboard;
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 56 * 1024; # 1024=1GiB
    }
  ];

  system = { inherit stateVersion; };

  systemd =
    let
      nix-systemd-slice = "nix";
      systemd-limits = rec {
        # Settings common to both sliceConfig and serviceConfig
        common = {
          Delegate = "yes";

          CPUAccounting = true;
          CPUQuota = lib.mkForce "75%";

          MemoryAccounting = true;
          MemoryHigh = lib.mkForce "67%";
          MemoryMax = lib.mkForce "75%";
        };

        # Settings valid only in `systemd.services.<name>.serviceConfig`
        service-only = {
          Slice = "${nix-systemd-slice}.slice";
        };

        # Settings valid only in `systemd.slices.<name>.sliceConfig`
        slice-only = { };

        service = common // service-only;
        slice = common // slice-only;
      };
    in
    {
      services = {
        journal-gc = {
          path = with pkgs; [ systemd ];
          script = ''
            shopt -s nullglob
            set -euxo pipefail

            journalctl --vacuum-time=2d
          '';
          serviceConfig.User = "root";
          startAt = "hourly";
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
        nix-daemon.serviceConfig = systemd-limits.service;
        nvidia-powerd = {
          after = [
            "systemd-modules-load.service"
            "nvidia-persistenced.service"
          ];
          requires = [ "nvidia-persistenced.service" ];
        };
        rebuild-nixos = {
          path = with pkgs; [
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
            set -euxo pipefail

            cd /etc/nixos
            nix flake update
            nix fmt

            if on_ac_power; then
                echo 'Computer is plugged in; continuing...'
            else
                echo 'Computer is not plugged in; aborting...'
                exit
            fi

            nh os build . ${nh-os-flags} --keep-going --max-jobs=1 --quiet

            git add -A
            git commit -m 'Automatic build succeeded' || :
            eval "$(ssh-agent -s)"
            ssh-add ~/.ssh/id_ed25519
            git push
            nh os switch . ${nh-os-flags} --quiet
          '';
          serviceConfig = systemd-limits.service // {
            User = "root";
          };
          startAt = "hourly";
        };
        supergfxd.path = [ pkgs.pciutils ];
      };

      slices.${nix-systemd-slice} = {
        enable = true;
        sliceConfig = systemd-limits.slice;
      };

      user.services.aura-keyboard = {
        description = "Keyboard backlight on login.";
        script = "asusctl aura effect rainbow-wave --direction right --speed low";
        wantedBy = [ "multi-user.target" ]; # starts after login
      };
    };

  users = {
    groups.${build-users-group} = { };
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
