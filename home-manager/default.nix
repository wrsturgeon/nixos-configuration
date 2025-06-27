{
  config,
  enable-hyprland,
  pkgs,
  username,
  ...
}:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home = {
    file = {
      ".aider.conf.yml".text = ''
        model: ollama_chat/gemma3:12b
      '';
      ".config/hypr/hyprland.conf".text = builtins.readFile ./hyprland.conf;
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
      without-hyprland = { };
    in
    if enable-hyprland then
      without-hyprland
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
    else
      without-hyprland;
}
