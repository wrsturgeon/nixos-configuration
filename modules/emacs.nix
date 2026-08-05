{ config, inputs, ... }:

let
  inherit (config.local) username;
in
{
  config.local.home-manager.users.${username} = { pkgs, ... }: {
    imports = [ inputs.doom-emacs.homeModule ];

    programs.doom-emacs = {
      enable = true;
      emacs = pkgs.emacs-pgtk;
    };

    # emacs-as-a-service
    services.emacs = {
      defaultEditor = true;
      enable = true;
      startWithUserSession = true;
    };
  };
}
