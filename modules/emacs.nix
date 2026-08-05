{ config, inputs, ... }:

let
  inherit (config.local) username;
in
{
  config.local.home-manager.users.${username} = { pkgs, ... }: {
    imports = [ inputs.doom-emacs.homeModule ];

    home = {
      packages =
        let
          aspell = pkgs.aspellWithDicts (
            dicts: with dicts; [
              en
              en-computers
              en-science
            ]
          );
        in
        [ aspell ] ++ (with pkgs; [ languagetool ]);
      shellAliases =
        let
          emacs-tty = "emacsclient -t";
        in
        {
          vi = emacs-tty;
          vim = emacs-tty;
          nvim = emacs-tty;
        };
    };

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
