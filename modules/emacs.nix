{ config, ... }:

let
  inherit (config.local) username;
in
{
  config.local.home-manager.users.${username} = { pkgs, ... }: {
    home.packages = [ pkgs.emacs-pgtk ];
  };
}
