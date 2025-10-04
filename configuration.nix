# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

all-flake-inputs@{
  config,
  desktop-and-shit,
  inputs,
  lib,
  pkgs,
  hostname,
  username,
  ...
}:

let
  limits = {
    memory = {
      throttle = lib.mkForce "67%";
      kill = lib.mkForce "75%";
    };
    cpu.quota = null; # lib.mkForce "90%";
  };

  rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml; # rust-bin.nightly.latest.default;

  build-users-group = "nixbld";
  num-build-users = 4;

  nh-clean-all-flags = "--keep-since 1d --optimise";
  nh-os-flags = "--bypass-root-check --fallback --keep-going --quiet";

  nix-systemd-slice = "nix";
  systemd-limits = rec {
    # Settings common to both sliceConfig and serviceConfig
    common = {
      Delegate = "yes";

      CPUAccounting = !(builtins.isNull limits.cpu.quota);
      CPUQuota = limits.cpu.quota;

      MemoryAccounting = true;
      MemoryHigh = limits.memory.throttle;
      MemoryMax = limits.memory.kill;
      # MemorySwapMax = limits.memory.kill;
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

  # wine = import ./wine.nix pkgs;
in
{
  # Use the systemd-boot EFI boot loader.
  boot = {
    tmp.cleanOnBoot = true;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  nix = {
    channel.enable = false;
    # gc = {
    #   automatic = true;
    #   options = "--delete-older-than 1d";
    # };
    # optimise.automatic = true;
    settings = {
      auto-optimise-store = true;
      inherit build-users-group;
      experimental-features = [
        "cgroups"
        "flakes"
        "nix-command"
      ];
      http-connections = 0; # unlimited
      log-lines = 48;
      max-jobs = num-build-users;
      min-free = "32G";
      preallocate-contents = true;
      pure-eval = true;
      require-sigs = true;
      sandbox = true;
      sandbox-dev-shm-size = "10%";
      sandbox-fallback = false;
      show-trace = true;
      stalled-download-timeout = 10; # seconds
      sync-before-registering = true;
      use-cgroups = true;
      use-xdg-base-directories = true;
      warn-large-path-threshold = "1G";
    };
  };

  nixpkgs = {
    config = {
      # allowUnfree = true;
      allowUnfreePredicate =
        let
          allowed = [
            "canon-cups-ufr2"
            "cuda-.*"
            "cuda_.*"
            "cudnn"
            "discord"
            "libcu.*"
            "libnpp"
            "libnv.*"
            "nvidia-.*"
            "spotify.*"
            "steam.*"
            "zoom"
          ];
        in
        pkg:
        let
          name = lib.getName pkg;
        in
        builtins.any (regex: !(builtins.isNull (builtins.match regex name))) allowed;
      cudaSupport = true;
      nvidia.acceptLicense = true;
    };
    overlays = [
      inputs.rust-overlay.overlays.default
    ]
    ++ (builtins.map (f: import "${./overlays}/${f}") (
      builtins.attrNames (builtins.readDir ./overlays)
    ));
  };

  networking.hostName = hostname; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  hardware = {
    bluetooth.enable = true;
    graphics.enable = true;
    nvidia = {
      dynamicBoost.enable = true;
      modesetting.enable = true;
      nvidiaSettings = true;
      open = true;
      package = with config.boot.kernelPackages.nvidiaPackages; stable;
      powerManagement = {
        enable = false; # until <https://nixos.wiki/wiki/Nvidia> says otherwise
        finegrained = false; # ^^ ditto
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

  security = {
    polkit.enable = true;
    rtkit.enable = true;
  };

  # Graphics & desktop:
  services = {
    asusd = {
      enable = true;
      enableUserService = true;
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    desktopManager = {
      plasma6.enable = desktop-and-shit == "kde-plasma";
      pantheon.enable = desktop-and-shit == "pantheon";
    };
    displayManager =
      if desktop-and-shit == "pantheon" then
        { }
      else
        {
          sddm = {
            enable = true;
            wayland.enable = true;
          };
        };

    goeland = {
      enable = true;
      schedule = "5m";
      settings = {
        loglevel = "info";
        include-footer = true;
        include-title = true;
        email = {
          host = "smtp.gmail.com";
          port = 587;
          username = "aw3s0m3.29";
          password_file = "/etc/secrets/email-password";
        };
        sources = {
          a16z = {
            url = "https://a16z.com/articles/feed/";
            type = "feed";
          };
        };
      };
    };

    # Enable touchpad support (enabled default in most desktopManager).
    libinput = {
      enable = true;
      touchpad = {
        clickMethod = "clickfinger";
        disableWhileTyping = true;
        naturalScrolling = true;
        tapping = false;
      };
    };

    minidlna = {
      enable = true;
      settings = {
        # media_dir = "/home/${username}/Videos";
        friendly_name = "Will's Bizarre Adventure";
      };
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    printing = {
      enable = true;
      drivers = with pkgs; [ canon-cups-ufr2 ];
    };

    supergfxd.enable = true;

    udev = {
      enable = true;
      packages = with pkgs; [
        openocd
        picotool
        platformio
        sane-airscan
        teensy-loader-cli
      ];
    };

    udisks2.enable = true;

    xserver = {
      enable = true;
      excludePackages = with pkgs; [ xterm ];
      videoDrivers = [ "nvidia" ];
      xkb.layout = "us";
    };
  };

  swapDevices = [
    {
      device = "/swapfile";
      size = 56 * 1024; # 1024=1GiB
    }
  ];

  systemd = {
    services = {
      nix-daemon.serviceConfig = systemd-limits.service;
      journal-gc = {
        path = with pkgs; [ systemd ];
        script = ''
          shopt -s nullglob
          set -euxo pipefail

          journalctl --vacuum-time=2d
        '';
        serviceConfig = systemd-limits.service // {
          User = "root";
        };
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
        serviceConfig = systemd-limits.service // {
          User = username;
        };
        startAt = "minutely";
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

          if on_ac_power; then
              echo 'Computer is plugged in; continuing...'
          else
              echo 'Computer is not plugged in; aborting...'
              exit
          fi

          cd /etc/nixos
          nix fmt
          nh os build . ${nh-os-flags} --update
          git add -A
          git commit -m 'Automatic build succeeded' || :
          eval "$(ssh-agent -s)"
          ssh-add ~/.ssh/id_ed25519
          git push
          nh os switch . ${nh-os-flags}
        '';
        serviceConfig = systemd-limits.service // {
          User = "root";
        };
        startAt = "daily"; # "hourly";
      };
      remove-result-symlinks = {
        script = ''
          set -euo pipefail
          on_ac_power || exit
          for f in /nix/var/nix/gcroots/auto/*; do
              export RESULT="$(readlink "''${f}")"
              if [[ ''${RESULT} == /home/* ]]; then
                  echo 'Removing `'"''${RESULT}"'`...'
                  rm -fr "''${RESULT}"
              fi
          done
        '';
        serviceConfig.User = "root";
        startAt = "daily";
      };
      supergfxd.path = [ pkgs.pciutils ];
    };

    slices."${nix-systemd-slice}" = {
      enable = true;
      sliceConfig = systemd-limits.slice;
    };

    user.services.aura-keyboard = {
      description = "Keyboard backlight on login.";
      script = "asusctl aura rainbox -s low"; # "asusctl aura static -c 0080ff";
      wantedBy = [ "multi-user.target" ]; # starts after login
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    groups."${build-users-group}" = { };
    users."${username}" = {
      isNormalUser = true;
      extraGroups = [
        "audio"
        "dialout" # USB
        "lp" # printing (& scanning?) documents
        "networkmanager"
        "scanner" # scanning documents
        "wheel" # `sudo`
      ];
      home = "/home/${username}";
      packages =
        (with pkgs; [
          discord
          haruna
          kicad
          lean4
          logseq
          spotify
          super-productivity
          tor-browser
          zoom-us
        ])
        # ++ (builtins.map wine (
        #   builtins.attrValues (builtins.mapAttrs (name: etc: etc // { inherit name; }) { ableton = { }; })
        # ))
        ++ (
          let
            common = [ ];
          in
          if desktop-and-shit == "hyprland" then
            common
            ++ (with pkgs; [
              clipse # Clipboard history
              hyprpolkitagent # Authentication pop-ups
              hyprpaper # Wallpaper selector
              hyprpicker # Color picker
              qt5.qtwayland
              qt6.qtwayland
              superfile # File browser
              swaynotificationcenter # Notification daemon
              tofi # App launcher
              xdg-desktop-portal-hyprland # Screen sharing
            ])
          else if desktop-and-shit == "kde-plasma" then
            common
          else if desktop-and-shit == "pantheon" then
            common
          else
            throw "Unrecognized desktop environment or window manager"
        )
        ++ (
          let
            python = pkgs.python3;
            zen-from-src = inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default;
            zen = pkgs.zen-browser or zen-from-src;
          in
          [
            python
            zen
          ]
        )
        ++ (builtins.map (src: import src all-flake-inputs) [
          # ./lean.nix
          # ./zen.nix
        ]);
      shell = pkgs.zsh;
    };
  };

  programs = {
    bash.completion.enable = true;
    direnv.enable = true;
    # firefox.enable = true;
    gamemode.enable = true;
    git = {
      enable = true;
      config = {
        commit.gpgsign = true;
        user = {
          name = "Will Sturgeon";
        };
      };
    };
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    hyprland = {
      enable = desktop-and-shit == "hyprland";
      withUWSM = true;
      xwayland = {
        # hidpi = true;
        enable = true;
      };

      # From <https://wiki.hyprland.org/Nix/Hyprland-on-NixOS>:
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage =
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    };
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
      extraPlugins = with pkgs.vimPlugins; [ Coqtail ];
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
        lean = { };
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
          servers = {
            clangd.enable = true;
            hls = {
              enable = true;
              installGhc = false;
            };
            hyprls.enable = true;
            lua_ls = {
              enable = true;
              settings.diagnostics.globals = [ "vim" ];
            };
            nil_ls.enable = true;
            nixd.enable = true;
            ocamllsp = {
              enable = true;
              package = null;
            };
            ruff.enable = true;
            rust_analyzer = {
              cargoPackage = rust-toolchain;
              enable = true;
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
                    "-Aclippy::multiple-crate-versions"
                    "-Aclippy::wildcard-dependencies"
                    "-Aclippy::wildcard-imports"
                  ];
                };
                checkOnSave = true;
                procMacro.enable = true;
              };
            };
            taplo.enable = true;
          };
        };
        lsp-format = {
          lspServersToEnable = "all";
        };
        lualine = {
          settings = {
            options.globalstatus = true;
          };
        };
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
        treesitter = {
          settings = {
            ensure_installed = "all";
            highlight.enable = true;
            ignore_install = [ "ipkg" ];
            incremental_selection.enable = true;
            indent.enable = true;
          };
        };
        web-devicons = { };
      };
      viAlias = true;
      vimAlias = true;
    };
    steam = {
      enable = true;
      package = pkgs.steam.override {
        extraPkgs =
          p: with p; [
            bumblebee
            glxinfo
          ];
      };
      protontricks.enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
    };
    waybar.enable = desktop-and-shit == "hyprland";
    zsh = {
      enableBashCompletion = true;
      enableCompletion = true;
      enable = true;
      promptInit = "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    };
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment = {
    shellAliases = {
      clippy = "cargo fmt && cargo clippy --all-features --all-targets --color=always 2>&1 | head -n 32";
      miri = "MIRIFLAGS=-Zmiri-env-forward=RUST_BACKTRACE RUST_BACKTRACE=1 cargo miri test --all-features";
    };
    shellInit = ''
      export OPENROUTER_API_KEY="$(< /etc/secrets/openrouter-key)"
    '';
    systemPackages = [
      rust-toolchain
    ]
    ++ (with pkgs; [
      binutils
      clang-tools
      coreutils-full
      gnumake
      killall
      libGL
      libGLU
      lshw
      mailspring
      nixfmt-rfc-style
      nvtopPackages.full
      openssl
      pkg-config
      pmutils
      procps
      ripgrep
      ruff
      screen
      stdenv.cc
      tree
      usbutils
      wezterm
      zip
    ])
    ++ (with pkgs; [
      # Rust shit:

      bacon # Background code checker
      cargo-audit # Check for security vulnerabilities in dependencies
      cargo-bloat # Inspect binaries for size of named items
      cargo-cross # Cross-compilation
      cargo-deny # Lint dependencies
      cargo-expand # Expand macros
      cargo-license # Print dependencies' licenses
      cargo-modules # Print crate API as a tree
      cargo-nextest # Alternate test runner
      cargo-outdated # Print out-of-date dependencies
      cargo-spellcheck # Documentation spell-checker
      cargo-tarpaulin # Code coverage
      cargo-unused-features # Find unused features
      cargo-zigbuild # Let Zig link your code
      evcxr # Rust REPL (Jupyter)
      lldb # LLVM debugger
      taplo # TOML formatter & LSP
    ])
    ++ (with pkgs.ocamlPackages; [
      # OCaml shit:

      dune_3
      ocaml
      ocamlformat
    ])
    ++ (with pkgs.rocqPackages; [
      # Rocq/Coq shit:

      rocq-core
      stdlib
    ])
    ++ (with pkgs.coqPackages; [
      coq # only until Coqtail updates
    ])
    ++ (with pkgs.cudaPackages; [
      cudnn
      cudatoolkit
    ])
    ++ (with pkgs.linuxPackages; [ nvidia_x11 ]);
    variables = {
      CARGO_NET_GIT_FETCH_WITH_CLI = "true";
      CUDA_PATH = "${pkgs.cudatoolkit}";
      EDITOR = "vi";
      # RUST_BACKTRACE = "1";
      WEZTERM_CONFIG_FILE = "${pkgs.writeTextFile {
        name = ".wezterm.lua";
        text = builtins.readFile ./.wezterm.lua;
      }}";
    };
  };

  fonts.packages =
    (with pkgs; [
      inter
      google-fonts
      source-serif
    ])
    ++ (with pkgs.nerd-fonts; [ iosevka-term ]);

  # xdg.portal = {
  #   enable = true;
  #   extraPortals = if desktop-and-shit == "hyprland" then with pkgs; [ xdg-desktop-portal-hyprland ] else [ ];
  # };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/unstable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/unstable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}
