# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

all-flake-inputs@{
  config,
  enable-hyprland,
  inputs,
  lib,
  pkgs,
  username,
  ...
}:

let
  display-manager = "sddm"; # "gdm";

  limits = {
    memory = {
      throttle = lib.mkForce "75%";
      kill = lib.mkForce "90%";
    };
    cpu.quota = lib.mkForce "90%";
  };

  rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml; # rust-bin.nightly.latest.default;

  build-users-group = "nixbld";
  num-build-users = 32;

  nix-systemd-slice = "nix";
  systemd-limits = rec {
    # Settings common to both sliceConfig and serviceConfig
    common = {
      Delegate = "yes";

      CPUAccounting = !(builtins.isNull limits.cpu.quota);
      MemoryAccounting = true;

      CPUQuota = limits.cpu.quota;

      MemoryHigh = limits.memory.throttle;
      MemoryMax = limits.memory.kill;
      MemorySwapMax = limits.memory.kill;
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
  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  nix = {
    channel.enable = false;
    gc = {
      automatic = true;
      options = "--delete-older-than 1d";
    };
    optimise.automatic = true;
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
      allowUnfree = true;
      cudaSupport = true;
      nvidia.acceptLicense = true;
    };
    overlays = [ inputs.rust-overlay.overlays.default ];
  };

  networking.hostName = "ENIAC"; # Define your hostname.
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
    graphics.enable = true;
    nvidia = {
      dynamicBoost.enable = true;
      modesetting.enable = true;
      nvidiaSettings = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      powerManagement = {
        enable = false; # until <https://nixos.wiki/wiki/Nvidia> says otherwise
        finegrained = false; # ^^ ditto
      };
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

    desktopManager.plasma6.enable = !enable-hyprland;
    displayManager."${display-manager}" = {
      enable = true;
      wayland.enable = true;
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

    ollama = {
      acceleration = "cuda";
      enable = true;
      loadModels = [
        "codellama:13b-instruct"
        "gemma3:12b"
      ];
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    supergfxd.enable = true;

    udev = {
      enable = true;
      packages = with pkgs; [ picotool ];
    };

    udisks2.enable = true;

    xserver = {
      enable = true;
      excludePackages = with pkgs; [ xterm ];
      videoDrivers = [ "nvidia" ];
      xkb.layout = "us";
    };
  };

  systemd = {
    services = {
      nix-daemon.serviceConfig = systemd-limits.service;
      rebuild-nixos = {
        path = with pkgs; [
          git
          nix
          nixos-rebuild
          pmutils
          sudo
          systemd
        ];
        script = ''
          set -euo pipefail
          on_ac_power || exit
          cd /etc/nixos
          nix flake update
          nix fmt
          nixos-rebuild switch --flake .#nixos --keep-going --sudo
          systemctl daemon-reexec
          systemctl restart nix-daemon
        '';
        serviceConfig = systemd-limits.service // {
          User = "root";
        };
        startAt = "hourly";
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
      description = "Rainbow keyboard on login.";
      script = "asusctl aura rainbow-wave";
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
        "networkmanager"
        "dialout" # USB
        "wheel" # Enable ‘sudo’ for the user.
      ];
      home = "/home/${username}";
      packages =
        (with pkgs; [
          aider-chat # -full
          discord
          haruna
          kicad
          logseq
          playwright
          spotify
        ])
        ++ (
          if enable-hyprland then
            with pkgs;
            [
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
            ]
          else
            [ ]
        )
        ++ (
          let
            python = pkgs.python3.withPackages (
              p: with p; [
                jax
                jaxlib
                jax-cuda12-plugin
                jax-cuda12-pjrt
              ]
            );
            zen-browser = inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default.override {
              nativeMessagingHosts = with pkgs; [ firefoxpwa ];
            };
          in
          [
            python
            zen-browser
          ]
        )
        ++ (builtins.map (src: import src all-flake-inputs) [
          # ./kicad.nix
          # ./aider.nix
        ]);
      shell = pkgs.zsh;
    };
  };

  programs = {
    bash.completion.enable = true;
    direnv.enable = true;
    # firefox.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    hyprland = {
      enable = enable-hyprland;
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
    nixvim = {
      colorschemes.ayu.enable = true;
      diagnostic.settings.virtual_text = true;
      enable = true;
      opts = rec {
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
        shell = "bash";
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
      plugins = builtins.mapAttrs (k: v: v // { enable = true; }) {
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
            ocamllsp.enable = true;
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
                  loadOutDirsFromCheck = true;
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
    waybar.enable = enable-hyprland;
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
    systemPackages =
      [ rust-toolchain ]
      ++ (with pkgs; [
        binutils
        coreutils-full
        git-credential-oauth
        gitFull
        gnumake
        libGL
        libGLU
        lshw
        nixfmt-rfc-style
        nvtopPackages.full
        openssl
        pkg-config
        pmutils
        procps
        ripgrep
        screen
        stdenv.cc
        thunderbird
        tree
        usbutils
        wezterm
      ])
      ++ (with pkgs; [
        # Rust shit:

        bacon # Background code checker
        cargo-audit # Check for security vulnerabilities in dependencies
        cargo-bloat # Inspect binaries for size of named items
        cargo-cross # Cross-compilation
        cargo-deny # Lint dependencies
        cargo-license # Print dependencies' licenses
        cargo-modules # Print crate API as a tree
        cargo-nextest # Alternate test runner
        cargo-outdated # Print out-of-date dependencies
        cargo-spellcheck # Documentation spell-checker
        cargo-tarpaulin # Code coverage
        cargo-unused-features # Find unused features
        cargo-zigbuild # Let Zig link your code
        evcxr # Rust REPL (Jupyter)
        taplo # TOML formatter & LSP
      ])
      ++ (with pkgs.cudaPackages; [
        cudnn
        cudatoolkit
      ])
      ++ (with pkgs.linuxPackages; [ nvidia_x11 ]);
    variables = {
      # __GLX_VENDOR_LIBRARY_NAME = "nvidia"; # Seems to break KiCAD.
      CARGO_NET_GIT_FETCH_WITH_CLI = "true";
      CUDA_PATH = "${pkgs.cudatoolkit}";
      EDITOR = "vi";
      GBM_BACKEND = "nvidia-drm";
      LIBVA_DRIVER_NAME = "nvidia";
      NIXOS_OZONE_WL = "1";
      NIXOS_XDG_OPEN_USE_PORTAL = "1";
      OLLAMA_API_BASE = "http://127.0.0.1:11434";
      SDL_VIDEODRIVER = "wayland";
      WEZTERM_CONFIG_FILE = "${pkgs.writeTextFile {
        name = ".wezterm.lua";
        text = builtins.readFile ./.wezterm.lua;
      }}";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
    };
  };

  fonts.packages =
    (with pkgs; [ inter ])
    ++ (with pkgs.nerd-fonts; [
      iosevka-term
    ]);

  # xdg.portal = {
  #   enable = true;
  #   extraPortals = if enable-hyprland then with pkgs; [ xdg-desktop-portal-hyprland ] else [ ];
  # };

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

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
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

}
