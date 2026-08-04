{ config, ... }:

let
  inherit (config.local) github-username nh-clean-all-flags;
in
{
  config.local.nixos.modules.host = { pkgs, ... }: {
    programs =
      builtins.mapAttrs
        (_k: v: if v.dontEnable or false then removeAttrs v [ "dontEnable" ] else ({ enable = true; } // v))
        {
          bash = {
            dontEnable = true;
            completion.enable = true;
          };
          dconf = { };
          direnv = { };
          fzf = {
            dontEnable = true;
            fuzzyCompletion = true;
            keybindings = true;
          };
          gamemode = { };
          git = {
            config = {
              commit.gpgsign = true;
              credential = {
                "https://gist.github.com" = {
                  helper = "!gh auth git-credential";
                  username = github-username;
                };
                "https://github.com" = {
                  helper = "!gh auth git-credential";
                  username = github-username;
                };
              };
              user = {
                email = "willstrgn@gmail.com";
                name = "Will Sturgeon";
              };
            };
            package = pkgs.gitFull;
          };
          gnupg = {
            dontEnable = true;
            agent = {
              enable = true;
              enableSSHSupport = true;
            };
          };
          hyprland = { };
          nh.clean = {
            dates = "*-*-* 04:00:00";
            enable = true;
            extraArgs = nh-clean-all-flags;
          };
          nix-index = { };
          zsh = {
            enableBashCompletion = true;
            enableCompletion = true;
            interactiveShellInit = ''
              fortune | cowsay -rn
              echo
            '';
            promptInit = ''
              case $(tty) in
                (/dev/tty*) :;;
                (*) source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme;;
              esac
            '';
          };
        };

  };
}
