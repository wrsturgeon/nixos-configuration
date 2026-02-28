args@{
  home,
  pkgs,
  stateVersion,
  username,
  ...
}:
{
  home = {
    inherit stateVersion username;
    pointerCursor = {
      enable = true;
      hyprcursor.enable = true;
      package = pkgs.rose-pine-hyprcursor;
      name = "cursor";
    };
    homeDirectory = home;
  };
  programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    home-manager = { };
    quickshell =
      let
        active-cfg-name = "nix";
      in
      {
        activeConfig = active-cfg-name;
        configs."${active-cfg-name}" = { };
        systemd.enable = true;
      };
    wezterm = {
      enableBashIntegration = true;
      enableZshIntegration = true;
      extraConfig = builtins.readFile ./wezterm.lua;
    };
  };
  services = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    hyprpaper.settings.wallpaper = {
      fit_mode = "cover";
      monitor = "";
      path = "~/Downloads/carlo-scarpa-tomba-brion-3.jpg";
    };
  };
  wayland.windowManager.hyprland = {
    enable = true;
    extraConfig = ''


      ################
      ### MONITORS ###
      ################

      # See https://wiki.hypr.land/Configuring/Monitors/
      monitor=,preferred,auto,1


      #################
      ### AUTOSTART ###
      #################

      # Autostart necessary processes (like notifications daemons, status bars, etc.)
      # Or execute your favorite apps at launch like this:

      exec-once = hyprpaper


      #############################
      ### ENVIRONMENT VARIABLES ###
      #############################

      # See https://wiki.hypr.land/Configuring/Environment-variables/

      env = XCURSOR_SIZE,24
      env = HYPRCURSOR_SIZE,24


      ###################
      ### PERMISSIONS ###
      ###################

      # See https://wiki.hypr.land/Configuring/Permissions/
      # Please note permission changes here require a Hyprland restart and are not applied on-the-fly
      # for security reasons

      # ecosystem {
      #   enforce_permissions = 1
      # }

      # permission = /usr/(bin|local/bin)/grim, screencopy, allow
      # permission = /usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland, screencopy, allow
      # permission = /usr/(bin|local/bin)/hyprpm, plugin, allow


      #####################
      ### LOOK AND FEEL ###
      #####################

      # Refer to https://wiki.hypr.land/Configuring/Variables/

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

      # See https://wiki.hypr.land/Configuring/Dwindle-Layout/ for more
      dwindle {
          pseudotile = true # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
          preserve_split = true # You probably want this
      }

      # See https://wiki.hypr.land/Configuring/Master-Layout/ for more
      master {
          new_status = master
      }


      ###################
      ### KEYBINDINGS ###
      ###################

      # Example binds, see https://wiki.hypr.land/Configuring/Binds/ for more
      bind = $mainMod, Q, exec, $terminal
      bind = $mainMod, C, killactive,
      bind = $mainMod, M, exec, command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit
      bind = $mainMod, E, exec, $fileManager
      bind = $mainMod, V, togglefloating,
      bind = $mainMod, R, exec, $menu
      bind = $mainMod, P, pseudo, # dwindle
      bind = $mainMod, J, layoutmsg, togglesplit # dwindle

      # Move focus with mainMod + arrow keys
      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d

      # Switch workspaces with mainMod + [0-9]
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      bind = $mainMod SHIFT, 1, movetoworkspace, 1
      bind = $mainMod SHIFT, 2, movetoworkspace, 2
      bind = $mainMod SHIFT, 3, movetoworkspace, 3
      bind = $mainMod SHIFT, 4, movetoworkspace, 4
      bind = $mainMod SHIFT, 5, movetoworkspace, 5
      bind = $mainMod SHIFT, 6, movetoworkspace, 6
      bind = $mainMod SHIFT, 7, movetoworkspace, 7
      bind = $mainMod SHIFT, 8, movetoworkspace, 8
      bind = $mainMod SHIFT, 9, movetoworkspace, 9
      bind = $mainMod SHIFT, 0, movetoworkspace, 10

      # Example special workspace (scratchpad)
      bind = $mainMod, S, togglespecialworkspace, magic
      bind = $mainMod SHIFT, S, movetoworkspace, special:magic

      # Scroll through existing workspaces with mainMod + scroll
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1

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
