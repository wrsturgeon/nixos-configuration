{
  desktop-and-shit,
  pkgs,
  username,
  ...
}:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    file = {
      ".config/hypr/hyprland.conf".text = builtins.readFile ./hyprland.conf;
      ".config/superProductivity/styles.css".text = builtins.readFile ./super-productivity.css;
    };
    inherit username;
    homeDirectory = "/home/${username}";
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      package = pkgs.gitFull;
    };
    git-credential-oauth.enable = true;
  };

  services =
    let
      common = { };
    in
    if desktop-and-shit == "hyprland" then
      common
      // {
        udiskie = {
          enable = true;
          settings = {
            # workaround for
            # https://github.com/nix-community/home-manager/issues/632
            program_options.file_manager = "${pkgs.wezterm}/bin/wezterm start -- ${pkgs.superfile}/bin/superfile";
          };
        };
      }
    else if desktop-and-shit == "kde-plasma" then
      common
    else if desktop-and-shit == "pantheon" then
      common
    else if desktop-and-shit == "darwin" then
      common
    else
      throw "Unrecognized desktop environment or window manager";
}
