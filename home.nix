args@{
  home,
  inputs,
  ollama-host,
  ollama-port,
  pkgs,
  stateVersion,
  username,
  ...
}:
let
  inherit (pkgs) stdenv;
  inherit (stdenv.targetPlatform) system;

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
      hyprlauncher
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
      yaml-language-server
      zls
      zulip
    ];
    pointerCursor = {
      enable = true;
      hyprcursor.enable = true;
      package = pkgs.rose-pine-hyprcursor;
      name = "cursor";
    };
    homeDirectory = home;
  };

  imports = [ inputs.zen-browser.homeModules.twilight ];

  programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    btop = { };
    home-manager = { };
    htop = { };
    hyprlock = { };
    opencode.settings = {
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
      theme = "system";
    };
    quickshell =
      let
        custom = "default";
      in
      {
        activeConfig = custom;
        configs.${custom} = ./quickshell;
        package = inputs.quickshell.packages.${system}.default.override {
          withX11 = false;
          withI3 = false;
        };
        systemd.enable = true;
      };
    wezterm = {
      enableBashIntegration = true;
      enableZshIntegration = true;
      extraConfig = builtins.readFile ./wezterm.lua;
    };
    yazi = { };
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
    hyprpaper.settings.wallpaper = {
      fit_mode = "cover";
      monitor = "";
      path = "~/Downloads/carlo-scarpa-tomba-brion-3.jpg";
    };
    hyprpolkitagent = { };
    ollama = {
      acceleration = "cuda";
      environmentVariables = {
        OLLAMA_CONTEXT_LENGTH = toString (
          64
          # 128
          * 1024
        );
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_NUM_PARALLEL = "1";
      };
      host = ollama-host;
      package = pkgs.ollama-cuda.overrideAttrs {
        src = inputs.ollama-src;
        version = "0.20.0";
      };
      port = ollama-port;
    };
    poweralertd = { };
    spotifyd.settings.global.bitrate = 320;
    swaync = { };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''


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
