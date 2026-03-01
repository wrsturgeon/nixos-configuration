{ keyboard, ... }:
{
  "$browser" = "zen-twilight";
  "$fileManager" = "wezterm start yazi";
  "$mainMod" = "SUPER";
  "$menu" = "hyprlauncher";
  "$music" = "wezterm start spotatui";
  "$terminal" = "wezterm";
  bind = [
    # Example binds, see https://wiki.hypr.land/Configuring/Binds/ for more
    "$mainMod, SPACE, exec, $menu"
    "$mainMod, B, exec, $browser"
    "$mainMod, C, killactive,"
    "$mainMod, D, exec, discord,"
    "$mainMod, E, exec, $fileManager" # E for explore
    "$mainMod, F, fullscreen, 0, toggle"
    "$mainMod, H, movefocus, l" # vim arrow key
    "$mainMod, J, movefocus, d" # vim arrow key
    "$mainMod, K, movefocus, u" # vim arrow key
    "$mainMod, L, movefocus, r" # vim arrow key
    "$mainMod, M, exec, $music"
    "$mainMod, P, pseudo, # dwindle" # huh?
    "$mainMod, Q, exec, command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"
    "$mainMod, R, layoutmsg, togglesplit # dwindle" # R for rotate
    "$mainMod, S, togglespecialworkspace, magic" # special workspace (scratchpad)
    "$mainMod SHIFT, S, movetoworkspace, special:magic" # special workspace (scratchpad)
    "$mainMod, T, exec, $terminal"

    # Switch workspaces with mainMod + [0-9]
    "$mainMod, 1, workspace, 1"
    "$mainMod, 2, workspace, 2"
    "$mainMod, 3, workspace, 3"
    "$mainMod, 4, workspace, 4"
    "$mainMod, 5, workspace, 5"
    "$mainMod, 6, workspace, 6"
    "$mainMod, 7, workspace, 7"
    "$mainMod, 8, workspace, 8"
    "$mainMod, 9, workspace, 9"
    "$mainMod, 0, workspace, 10"

    # Move active window to a workspace with mainMod + SHIFT + [0-9]
    "$mainMod SHIFT, 1, movetoworkspace, 1"
    "$mainMod SHIFT, 2, movetoworkspace, 2"
    "$mainMod SHIFT, 3, movetoworkspace, 3"
    "$mainMod SHIFT, 4, movetoworkspace, 4"
    "$mainMod SHIFT, 5, movetoworkspace, 5"
    "$mainMod SHIFT, 6, movetoworkspace, 6"
    "$mainMod SHIFT, 7, movetoworkspace, 7"
    "$mainMod SHIFT, 8, movetoworkspace, 8"
    "$mainMod SHIFT, 9, movetoworkspace, 9"
    "$mainMod SHIFT, 0, movetoworkspace, 10"

    # Scroll through existing workspaces with mainMod + scroll
    "$mainMod, mouse_down, workspace, e+1"
    "$mainMod, mouse_up, workspace, e-1"
  ];
  debug.disable_logs = false;
  decoration = {
    active_opacity = 1.0;
    blur = {
      enabled = true;
      passes = 2;
      size = 5; # 3;
    };
    inactive_opacity = 0.85;
    rounding = 8; # 10
    rounding_power = 2;
  };
  dwindle = {
    pseudotile = true; # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = true; # You probably want this
  };
  general = {
    border_size = 1;
    "col.active_border" = "rgb(ffffff) rgb(000000) 45deg";
    "col.inactive_border" = "rgb(606060) rgb(a0a0a0) 45deg";
    gaps_in = 2; # 5;
    gaps_out = 8; # 20;
    layout = "dwindle";
    resize_on_border = true;
  };
  gesture = "3, horizontal, workspace";
  input = {
    follow_mouse = 2;
    kb_layout = keyboard.layout;
    kb_options = keyboard.options;
    kb_variant = keyboard.variant;
    repeat_rate = 100;
    repeat_delay = 150;
    sensitivity = 2.0;
    touchpad = {
      clickfinger_behavior = true;
      natural_scroll = true;
      tap-to-click = false;
    };
  };
  misc = {
    font_family = "Inter";
    splash_font_family = "Inter";
  };
  monitor = ",preferred,auto,1";
  xwayland.force_zero_scaling = true;
}
