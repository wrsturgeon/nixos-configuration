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
  programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    home-manager = { };
    wezterm = {
      enableBashIntegration = true;
      enableZshIntegration = true;
      extraConfig = builtins.readFile ./.wezterm.lua;
    };
  };
  wayland.windowManager.hyprland = {
    enable = compositor == "hyprland";
    package = null;
    portalPackage = null;
    systemd.variables = [ "--all" ];
  };
}
