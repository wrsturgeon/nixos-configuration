{ config, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local)
    default-font
    home
    stateVersion
    username
    ;
in
{
  config.local.home-manager.users.${username} = { pkgs, ... }: {
    dconf.settings."org/gnome/desktop/interface".font-hinting = "full";

    gtk = {
      enable = true;
      font.name = default-font;
    };
    home = {
      inherit stateVersion username;
      file = {
        ".agents/skills/enlightenment.md" = {
          force = true;
          text = builtins.readFile ../worse-is-better-monologue.md;
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

    imports = [ flakeConfig.local.home-manager.modules.pi ];
  };
}
