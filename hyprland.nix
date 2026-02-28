{ keyboard, ... }:
{
  "$fileManager" = "nemo";
  "$mainMod" = "SUPER";
  "$menu" = "hyprlauncher";
  "$terminal" = "wezterm";
  debug.disable_logs = false;
  decoration = {
    active_opacity = 1.0;
    blur = {
      enabled = true;
      passes = 2;
      size = 5; # 3;
    };
    inactive_opacity = 0.9;
    rounding = 8; # 10
    rounding_power = 2;
    # shadow = {
    #   color = "rgba(1a1a1aee)";
    #   enabled = true;
    #   range = 4;
    #   render_power = 3;
    # };
  };
  general = {
    border_size = 2;
    "col.active_border" = "rgba(ffffffff) rgba(000000ff) 45deg";
    "col.inactive_border" = "rgba(606060ff) rgba(a0a0a0ff) 45deg";
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
}
