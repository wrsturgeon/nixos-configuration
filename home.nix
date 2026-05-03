args@{
  home,
  inputs,
  lib,
  ollama-host,
  ollama-port,
  pkgs,
  stateVersion,
  username,
  ...
}:
let

  caelestia-wallpaper = inputs.desktop-background;
  neovimAyuSource = builtins.readFile "${pkgs.vimPlugins.neovim-ayu}/lua/ayu/colors.lua";
  neovimAyuDarkBlock =
    let
      partsAfterMirage = lib.splitString "    else\n      colors.accent = '#E6B450'\n" neovimAyuSource;
      darkTail = builtins.elemAt partsAfterMirage 1;
      darkBody = builtins.elemAt (lib.splitString "    end\n  else\n" darkTail) 0;
    in
    "      colors.accent = '#E6B450'\n" + darkBody;
  neovimAyuDark =
    let
      lines = lib.splitString "\n" neovimAyuDarkBlock;
      colour =
        name:
        let
          matches = builtins.filter (
            line: builtins.match "[[:space:]]*colors\\.${name} = '([^']+)'" line != null
          ) lines;
        in
        builtins.elemAt (builtins.match "[[:space:]]*colors\\.${name} = '([^']+)'" (builtins.elemAt matches 0)) 0;
    in
    {
      accent = colour "accent";
      background = colour "bg";
      foreground = colour "fg";
      ui = colour "ui";
      tag = colour "tag";
      func = colour "func";
      entity = colour "entity";
      string = colour "string";
      regexp = colour "regexp";
      markup = colour "markup";
      comment = colour "comment";
      constant = colour "constant";
      error = colour "error";
      line = colour "line";
      panelBg = colour "panel_bg";
      selectionBg = colour "selection_bg";
    };
  neovimAyuToCaelestia =
    {
      name,
      flavour ? "default",
      mode ? "dark",
      variant ? "content",
      palette,
    }:
    let
      clean = colour: lib.removePrefix "#" colour;
      p = builtins.mapAttrs (_: clean) palette;
      ansi = with p; [
        background
        markup
        string
        accent
        tag
        constant
        regexp
        foreground
      ];
      brights = with p; [
        ui
        error
        string
        accent
        tag
        constant
        regexp
        comment
      ];
      c = builtins.mapAttrs (_: clean) {
        inherit (palette) background;
        inherit (palette) foreground;
        cursor = palette.func;
        selection = palette.selectionBg;
        surfaceContainer = palette.panelBg;
        black = builtins.elemAt ansi 0;
        red = builtins.elemAt ansi 1;
        green = builtins.elemAt ansi 2;
        yellow = builtins.elemAt ansi 3;
        blue = builtins.elemAt ansi 4;
        magenta = builtins.elemAt ansi 5;
        cyan = builtins.elemAt ansi 6;
        white = builtins.elemAt ansi 7;
        brightBlack = builtins.elemAt brights 0;
        brightRed = builtins.elemAt brights 1;
        brightGreen = builtins.elemAt brights 2;
        brightYellow = builtins.elemAt brights 3;
        brightBlue = builtins.elemAt brights 4;
        brightMagenta = builtins.elemAt brights 5;
        brightCyan = builtins.elemAt brights 6;
        brightWhite = builtins.elemAt brights 7;
      };
      colours = {
        primary_paletteKeyColor = c.blue;
        secondary_paletteKeyColor = c.cyan;
        tertiary_paletteKeyColor = c.yellow;
        neutral_paletteKeyColor = c.foreground;
        neutral_variant_paletteKeyColor = c.brightBlack;
        inherit (c) background;
        onBackground = c.foreground;
        surface = c.background;
        surfaceDim = c.background;
        surfaceBright = c.brightBlack;
        surfaceContainerLowest = c.black;
        surfaceContainerLow = c.background;
        inherit (c) surfaceContainer;
        surfaceContainerHigh = c.selection;
        surfaceContainerHighest = c.selection;
        onSurface = c.foreground;
        surfaceVariant = c.selection;
        onSurfaceVariant = c.brightWhite;
        inverseSurface = c.foreground;
        inverseOnSurface = c.background;
        outline = c.brightBlack;
        outlineVariant = c.selection;
        shadow = "000000";
        scrim = "000000";
        surfaceTint = c.blue;
        primary = c.blue;
        onPrimary = c.background;
        primaryContainer = c.selection;
        onPrimaryContainer = c.brightBlue;
        inversePrimary = c.brightBlue;
        primaryFixed = c.brightBlue;
        primaryFixedDim = c.blue;
        onPrimaryFixed = c.background;
        onPrimaryFixedVariant = c.foreground;
        secondary = c.cyan;
        onSecondary = c.background;
        secondaryContainer = c.selection;
        onSecondaryContainer = c.brightCyan;
        secondaryFixed = c.brightCyan;
        secondaryFixedDim = c.cyan;
        onSecondaryFixed = c.background;
        onSecondaryFixedVariant = c.foreground;
        tertiary = c.yellow;
        onTertiary = c.background;
        tertiaryContainer = c.selection;
        onTertiaryContainer = c.brightYellow;
        tertiaryFixed = c.brightYellow;
        tertiaryFixedDim = c.yellow;
        onTertiaryFixed = c.background;
        onTertiaryFixedVariant = c.foreground;
        error = c.brightRed;
        onError = c.background;
        errorContainer = c.selection;
        onErrorContainer = c.brightRed;
        term0 = c.black;
        term1 = c.red;
        term2 = c.green;
        term3 = c.yellow;
        term4 = c.blue;
        term5 = c.magenta;
        term6 = c.cyan;
        term7 = c.white;
        term8 = c.brightBlack;
        term9 = c.brightRed;
        term10 = c.brightGreen;
        term11 = c.brightYellow;
        term12 = c.brightBlue;
        term13 = c.brightMagenta;
        term14 = c.brightCyan;
        term15 = c.brightWhite;
        rosewater = c.foreground;
        flamingo = c.magenta;
        pink = c.brightMagenta;
        mauve = c.magenta;
        inherit (c) red;
        maroon = c.brightRed;
        peach = c.yellow;
        yellow = c.brightYellow;
        inherit (c) green;
        teal = c.cyan;
        sky = c.brightCyan;
        sapphire = c.blue;
        blue = c.brightBlue;
        lavender = c.brightBlue;
        klink = c.blue;
        klinkSelection = c.blue;
        kvisited = c.magenta;
        kvisitedSelection = c.magenta;
        knegative = c.brightRed;
        knegativeSelection = c.brightRed;
        kneutral = c.yellow;
        kneutralSelection = c.yellow;
        kpositive = c.green;
        kpositiveSelection = c.green;
        text = c.foreground;
        subtext1 = c.brightWhite;
        subtext0 = c.brightBlack;
        overlay2 = c.brightBlack;
        overlay1 = c.selection;
        overlay0 = c.selection;
        surface2 = c.selection;
        surface1 = c.brightBlack;
        surface0 = c.background;
        base = c.background;
        mantle = c.background;
        crust = c.black;
        success = c.green;
        onSuccess = c.background;
        successContainer = c.selection;
        onSuccessContainer = c.brightGreen;
      };
    in
    {
      inherit
        name
        flavour
        mode
        variant
        colours
        ;
    };
  ayuCaelestiaScheme = neovimAyuToCaelestia {
    name = "ayu";
    palette = neovimAyuDark;
  };
  opencode-backend = "ollama";
  opencode-model = "gemma4:26b"; # "gpt-oss:20b";
in
{
  home = {
    inherit stateVersion username;
    packages = with pkgs; [
      bash-language-server
      discord
      element-desktop # matrix
      haskell-language-server
      libreoffice-qt6
      logseq
      luajitPackages.lua-lsp
      mailspring
      nixd
      ocamlPackages.ocaml-lsp
      pyright
      rust-analyzer
      super-productivity
      tor-browser
      wayneko
      yaml-language-server
      zls
      zulip
    ];
    file = {
      ".local/state/caelestia/wallpaper/current" = {
        force = true;
        source = caelestia-wallpaper;
      };
      ".local/state/caelestia/wallpaper/path.txt" = {
        force = true;
        text = "${caelestia-wallpaper}\n";
      };
      ".local/state/caelestia/scheme.json" = {
        force = true;
        text = builtins.toJSON ayuCaelestiaScheme;
      };
    };
    pointerCursor = {
      enable = true;
      hyprcursor.enable = true;
      package = pkgs.rose-pine-hyprcursor;
      name = "cursor";
    };
    homeDirectory = home;
  };

  imports = [
    inputs.caelestia-shell.homeManagerModules.default
    inputs.zen-browser.homeModules.twilight
  ];

  programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    btop = { };
    codex = { };
    gh = {
      gitCredentialHelper.enable = false;
      settings = {
        git_protocol = "https";
        prompt = "enabled";
      };
    };
    home-manager = { };
    htop = { };
    hyprlock = { };
    caelestia = {
      cli.enable = true;
      cli.settings.theme.enableTerm = false;
      settings = {
        # https://github.com/caelestia-dots/shell#example-configuration
        appearance = {
          anim.durations.scale = 0.5;
          deformScale = 0.5;
          font.family = {
            clock = "Iosevka Custom";
            mono = "Iosevka Custom";
            sans = "Inter";
          };
          rounding.scale = 0.5;
        };
        bar = {
          activeWindow.showOnHover = false;
          clock.showDate = true;
          status = {
            showAudio = true;
            showKbLayout = true;
            showMicrophone = true;
          };
          workspaces.shown = 8;
        };
        border = {
          rounding = 8;
          thickness = 0;
        };
        launcher = {
          showOnHover = true;
          vimKeybinds = true;
        };
        services = {
          useFahrenheit = true;
          useTwelveHourClock = true;
        };
        session.vimKeybinds = true;
      };
    };
    opencode = {
      settings = {
        "$schema" = "https://opencode.ai/config.json";
        agent.build = {
          mode = "primary";
          model = "${opencode-backend}/${opencode-model}";
          tools."*" = true;
        };
        model = "${opencode-backend}/${opencode-model}";
        permission = {
          bash = "allow";
          edit = "allow";
          glob = "allow";
          grep = "allow";
          list = "allow";
          lsp = "allow";
          question = "allow";
          read = "allow";
          skill = "allow";
          todoread = "allow";
          todowrite = "allow";
          webfetch = "allow";
          websearch = "allow";
        };
        provider = {
          # "llama.cpp" = {
          #   npm = "@ai-sdk/openai-compatible";
          #   name = "llama.cpp";
          #   options.baseURL = "http://${llama-cpp-host}:${toString llama-cpp-port}/v1";
          #   models.bonsai = { };
          # };
          ollama = {
            npm = "@ai-sdk/openai-compatible";
            name = "ollama";
            options.baseURL = "http://${ollama-host}:${toString ollama-port}/v1";
            models."${opencode-model}" = { };
          };
        };
      };
      tui = {
        theme = "system";
      };
    };
    wezterm = {
      enableBashIntegration = true;
      enableZshIntegration = true;
      extraConfig = builtins.readFile ./wezterm.lua;
    };
    zen-browser = {
      # nativeMessagingHosts = with pkgs; [ firefoxpwa ];
    };
  };

  services = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    hypridle.settings.listener =
      let
        timeout = 120;
        grace-period = 10;
      in
      [
        {
          on-resume = "brightnessctl -r";
          on-timeout = "brightnessctl -s set 1";
          timeout = timeout - grace-period;
        }
        {
          inherit timeout;
          on-timeout = "hyprlock";
        }
      ];
    hyprpolkitagent = { };
    ollama = {
      acceleration = "cuda";
      environmentVariables = {
        OLLAMA_CONTEXT_LENGTH = toString (
          64
          # 128
          * 1024
        );
        OLLAMA_DEBUG = "2";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_NUM_PARALLEL = "1";
      };
      host = ollama-host;
      port = ollama-port;
    };
    poweralertd = { };
    spotifyd.settings.global.bitrate = 320;
  };

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''

      exec-once = ${pkgs.wayneko}/bin/wayneko --layer overlay


      #####################
      ### LOOK AND FEEL ###
      #####################

      # https://wiki.hypr.land/Configuring/Variables/#animations
      animations {
          enabled = yes, please :)

          # Default curves, see https://wiki.hypr.land/Configuring/Animations/#curves
          #        NAME,           X0,   Y0,   X1,   Y1
          bezier = easeOutQuint,   0.23, 1,    0.32, 1
          bezier = easeInOutCubic, 0.65, 0.05, 0.36, 1
          bezier = linear,         0,    0,    1,    1
          bezier = almostLinear,   0.5,  0.5,  0.75, 1
          bezier = quick,          0.15, 0,    0.1,  1

          # Default animations, see https://wiki.hypr.land/Configuring/Animations/
          #           NAME,          ONOFF, SPEED, CURVE,        [STYLE]
          animation = global,        1,     10,    default
          animation = border,        1,     5.39,  easeOutQuint
          animation = windows,       1,     4.79,  easeOutQuint
          animation = windowsIn,     1,     4.1,   easeOutQuint, popin 87%
          animation = windowsOut,    1,     1.49,  linear,       popin 87%
          animation = fadeIn,        1,     1.73,  almostLinear
          animation = fadeOut,       1,     1.46,  almostLinear
          animation = fade,          1,     3.03,  quick
          animation = layers,        1,     3.81,  easeOutQuint
          animation = layersIn,      1,     4,     easeOutQuint, fade
          animation = layersOut,     1,     1.5,   linear,       fade
          animation = fadeLayersIn,  1,     1.79,  almostLinear
          animation = fadeLayersOut, 1,     1.39,  almostLinear
          animation = workspaces,    1,     1.94,  almostLinear, fade
          animation = workspacesIn,  1,     1.21,  almostLinear, fade
          animation = workspacesOut, 1,     1.94,  almostLinear, fade
          animation = zoomFactor,    1,     7,     quick
      }


      ###################
      ### KEYBINDINGS ###
      ###################

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      # Laptop multimedia keys for volume and LCD brightness
      bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+
      bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-
      bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
      bindel = ,XF86MonBrightnessUp, exec, brightnessctl -e4 -n1% set 10%+
      bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n1% set 10%-
      bindel = ,XF86KbdBrightnessDown, exec, asusctl leds set off
      bindel = ,XF86KbdBrightnessUp, exec, asusctl leds set low

      # Requires playerctl
      bindl = , XF86AudioNext, exec, playerctl next
      bindl = , XF86AudioPause, exec, playerctl play-pause
      bindl = , XF86AudioPlay, exec, playerctl play-pause
      bindl = , XF86AudioPrev, exec, playerctl previous

      ##############################
      ### WINDOWS AND WORKSPACES ###
      ##############################

      # See https://wiki.hypr.land/Configuring/Window-Rules/ for more
      # See https://wiki.hypr.land/Configuring/Workspace-Rules/ for workspace rules

      # Example windowrules that are useful

      windowrule {
          # Ignore maximize requests from all apps. You'll probably like this.
          name = suppress-maximize-events
          match:class = .*

          suppress_event = maximize
      }

      windowrule {
          # Fix some dragging issues with XWayland
          name = fix-xwayland-drags
          match:class = ^$
          match:title = ^$
          match:xwayland = true
          match:float = true
          match:fullscreen = false
          match:pin = false

          no_focus = true
      }

      # Hyprland-run windowrule
      windowrule {
          name = move-hyprland-run

          match:class = hyprland-run

          move = 20 monitor_h-120
          float = yes
      }
    '';
    package = null;
    portalPackage = null;
    settings = import ./hyprland.nix args;
    systemd.variables = [ "--all" ];
  };
}
