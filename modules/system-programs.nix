{ config, ... }:

let
  inherit (config.local) github-username nh-clean-all-flags;
in
{
  config.local.nixos.modules.host = { pkgs, ... }: {
    programs = {
      bash.completion.enable = true;
      dconf.enable = true;
      direnv.enable = true;
      fzf = {
        fuzzyCompletion = true;
        keybindings = true;
      };
      gamemode.enable = true;
      git = {
        enable = true;
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
      gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
      };
      nh = {
        enable = true;
        clean = {
          dates = "*-*-* 04:00:00";
          enable = true;
          extraArgs = nh-clean-all-flags;
        };
      };
      nix-index.enable = true;
      zsh = {
        enable = true;
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
