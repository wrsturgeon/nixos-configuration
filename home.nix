{
  compositor,
  home,
  stateVersion,
  username,
  ...
}:
{
  home = {
    homeDirectory = home;
    inherit stateVersion username;
  };
  programs.home-manager.enable = true;
  wayland.windowManager.hyprland.enable = compositor == "hyprland";
}
