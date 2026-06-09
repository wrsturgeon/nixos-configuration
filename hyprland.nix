{
  default-font,
  default-serif-font,
  keyboard,
  lib,
  pkgs,
  taskCapture,
  taskDashboard,
  ...
}:
let
  lua = lib.generators.mkLuaInline;

  browser = "zen-twilight";
  mainMod = "SUPER";
  menu = "caelestia shell drawers toggle launcher";
  music = "spotify";
  processViewer = "wezterm start btop";
  terminal = "wezterm";
  waynekoCommand = "${pkgs.wayneko}/bin/wayneko --layer overlay";

  bind = keys: dispatcher: {
    _args = [
      keys
      (lua dispatcher)
    ];
  };

  bindWith = keys: dispatcher: flags: {
    _args = [
      keys
      (lua dispatcher)
      flags
    ];
  };

  exec = command: "hl.dsp.exec_cmd(${builtins.toJSON command})";

  workspaceKey = workspace: if workspace == 10 then "0" else toString workspace;
  workspaces = lib.range 1 10;
  workspaceFocusBinds = map (
    workspace:
    bind "${mainMod} + ${workspaceKey workspace}" "hl.dsp.focus({ workspace = ${toString workspace} })"
  ) workspaces;
  workspaceMoveBinds = map (
    workspace:
    bind "${mainMod} + SHIFT + ${workspaceKey workspace}" "hl.dsp.window.move({ workspace = ${toString workspace} })"
  ) workspaces;
in
{
  config = {
    animations.enabled = false; # true
    debug.disable_logs = false;
    decoration = {
      active_opacity = 1.0;
      blur = {
        enabled = true;
        passes = 2;
        size = 5;
      };
      inactive_opacity = 0.8;
      rounding = 8;
      rounding_power = 2;
    };
    dwindle.preserve_split = true;
    general = {
      border_size = 1;
      col = {
        active_border = {
          colors = [
            "rgb(ffffff)"
            "rgb(000000)"
          ];
          angle = 45;
        };
        inactive_border = {
          colors = [
            "rgb(606060)"
            "rgb(a0a0a0)"
          ];
          angle = 45;
        };
      };
      gaps_in = 2;
      gaps_out = 8;
      layout = "dwindle";
      resize_on_border = true;
    };
    input = {
      follow_mouse = 0;
      kb_layout = keyboard.layout;
      kb_options = keyboard.options;
      kb_variant = keyboard.variant;
      repeat_rate = 100;
      repeat_delay = 150;
      sensitivity = 2.0;
      touchpad = {
        clickfinger_behavior = true;
        natural_scroll = true;
        tap_to_click = false;
      };
    };
    misc = {
      allow_session_lock_restore = true;
      font_family = default-font;
      splash_font_family = "${default-serif-font} Italic";
    };
    xwayland.force_zero_scaling = true;
  };

  monitor = [
    {
      output = "";
      mode = "preferred";
      position = "auto";
      scale = 1;
    }
    {
      output = "HDMI-A-3";
      mode = "preferred";
      position = "auto";
      scale = 1;
      mirror = "eDP-1";
    }
  ];

  gesture = {
    fingers = 3;
    direction = "horizontal";
    action = "workspace";
  };

  # curve = [
  #   (bezier "easeOutQuint" [ 0.23 1 ] [ 0.32 1 ])
  #   (bezier "easeInOutCubic" [ 0.65 0.05 ] [ 0.36 1 ])
  #   (bezier "linear" [ 0 0 ] [ 1 1 ])
  #   (bezier "almostLinear" [ 0.5 0.5 ] [ 0.75 1 ])
  #   (bezier "quick" [ 0.15 0 ] [ 0.1 1 ])
  # ];
  #
  # animation =
  #   let
  #     animation =
  #       leaf: speed: bezierName: extra:
  #       {
  #         inherit leaf speed;
  #         enabled = true;
  #         bezier = bezierName;
  #       }
  #       // extra;
  #   in
  #   [
  #     (animation "global" 10 "default" { })
  #     (animation "border" 5.39 "easeOutQuint" { })
  #     (animation "windows" 4.79 "easeOutQuint" { })
  #     (animation "windowsIn" 4.1 "easeOutQuint" { style = "popin 87%"; })
  #     (animation "windowsOut" 1.49 "linear" { style = "popin 87%"; })
  #     (animation "fadeIn" 1.73 "almostLinear" { })
  #     (animation "fadeOut" 1.46 "almostLinear" { })
  #     (animation "fade" 3.03 "quick" { })
  #     (animation "layers" 3.81 "easeOutQuint" { })
  #     (animation "layersIn" 4 "easeOutQuint" { style = "fade"; })
  #     (animation "layersOut" 1.5 "linear" { style = "fade"; })
  #     (animation "fadeLayersIn" 1.79 "almostLinear" { })
  #     (animation "fadeLayersOut" 1.39 "almostLinear" { })
  #     (animation "workspaces" 1.94 "almostLinear" { style = "fade"; })
  #     (animation "workspacesIn" 1.21 "almostLinear" { style = "fade"; })
  #     (animation "workspacesOut" 1.94 "almostLinear" { style = "fade"; })
  #     (animation "zoomFactor" 7 "quick" { })
  #   ];

  bind = [
    (bind "${mainMod} + SPACE" (exec menu))
    (bind "${mainMod} + B" (exec browser))
    (bind "${mainMod} + C" (exec "${taskCapture}/bin/task-capture"))
    (bind "${mainMod} + D" (exec "discord"))
    (bind "${mainMod} + E" (exec "emacs"))
    (bind "${mainMod} + F" ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'')
    (bind "${mainMod} + H" ''hl.dsp.focus({ direction = "left" })'')
    (bind "${mainMod} + J" ''hl.dsp.focus({ direction = "down" })'')
    (bind "${mainMod} + K" ''hl.dsp.focus({ direction = "up" })'')
    (bind "${mainMod} + L" ''hl.dsp.focus({ direction = "right" })'')
    (bind "${mainMod} + M" (exec music))
    (bind "${mainMod} + N" (exec "logseq"))
    (bind "${mainMod} + P" (exec processViewer))
    (bind "${mainMod} + O" (exec "wezterm start --cwd=/etc/nixos sudo zsh -l"))
    # (bind "${mainMod} + Q" (
    #   exec "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"
    # ))
    (bind "${mainMod} + S" ''hl.dsp.workspace.toggle_special("magic")'')
    (bind "${mainMod} + SHIFT + S" ''hl.dsp.window.move({ workspace = "special:magic" })'')
    (bind "${mainMod} + T" (exec terminal))
    (bind "${mainMod} + V" ''hl.dsp.layout("togglesplit")'') # V for vertical
    (bind "${mainMod} + W" "hl.dsp.window.close()") # W for window-close (as is usual in browsers)
    (bind "${mainMod} + Y" (exec "${taskDashboard}/bin/task-dashboard"))
  ]
  ++ workspaceFocusBinds
  ++ workspaceMoveBinds
  ++ [
    (bind "${mainMod} + mouse_down" ''hl.dsp.focus({ workspace = "e+1" })'')
    (bind "${mainMod} + mouse_up" ''hl.dsp.focus({ workspace = "e-1" })'')
    (bindWith "${mainMod} + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
    (bindWith "${mainMod} + mouse:273" "hl.dsp.window.resize()" { mouse = true; })
    (bindWith "XF86AudioRaiseVolume" (exec "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 10%+") {
      locked = true;
      repeating = true;
    })
    (bindWith "XF86AudioLowerVolume" (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-") {
      locked = true;
      repeating = true;
    })
    (bindWith "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") {
      locked = true;
      repeating = true;
    })
    (bindWith "XF86AudioMicMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") {
      locked = true;
      repeating = true;
    })
    (bindWith "XF86MonBrightnessUp" (exec "brightnessctl -e4 -n1% set 10%+") {
      locked = true;
      repeating = true;
    })
    (bindWith "XF86MonBrightnessDown" (exec "brightnessctl -e4 -n1% set 10%-") {
      locked = true;
      repeating = true;
    })
    (bindWith "XF86KbdBrightnessDown" (exec "asusctl leds set off") {
      locked = true;
      repeating = true;
    })
    (bindWith "XF86KbdBrightnessUp" (exec "asusctl leds set low") {
      locked = true;
      repeating = true;
    })
    (bindWith "XF86AudioNext" (exec "playerctl next") { locked = true; })
    (bindWith "XF86AudioPause" (exec "playerctl play-pause") { locked = true; })
    (bindWith "XF86AudioPlay" (exec "playerctl play-pause") { locked = true; })
    (bindWith "XF86AudioPrev" (exec "playerctl previous") { locked = true; })
    (bindWith "XF86AudioStop" (exec "playerctl stop") { locked = true; })
  ];

  on = {
    _args = [
      "hyprland.start"
      (lua ''
        function()
          hl.exec_cmd(${builtins.toJSON waynekoCommand})
        end
      '')
    ];
  };

  window_rule = [
    {
      name = "suppress-maximize-events";
      match.class = ".*";
      suppress_event = "maximize";
    }
    {
      name = "fix-xwayland-drags";
      match = {
        class = "^$";
        title = "^$";
        xwayland = true;
        float = true;
        fullscreen = false;
        pin = false;
      };
      no_focus = true;
    }
    {
      name = "move-hyprland-run";
      match.class = "hyprland-run";
      move = [
        20
        "monitor_h-120"
      ];
      float = true;
    }
    {
      name = "task-dashboard";
      match.class = "taskwarrior-tui";
      workspace = "special:tasks";
    }
  ];
}
