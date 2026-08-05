{ config, inputs, ... }:

let
  inherit (config.local) home username;
in
{
  config.local.home-manager.users.${username} = { lib, pkgs, ... }: {
    home = {
      activation.refuseAmbiguousSpacemacsState = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        emacs_file=${lib.escapeShellArg "${home}/.emacs"}
        spacemacs_init=${lib.escapeShellArg "${home}/.emacs.d/init.el"}

        if [ -e "$emacs_file" ] || [ -L "$emacs_file" ]; then
          echo "Refusing to activate Spacemacs because $emacs_file exists." >&2
          echo "Move it aside first; Emacs loads ~/.emacs before ~/.emacs.d/init.el." >&2
          exit 1
        fi

        if [ -e "$spacemacs_init" ] || [ -L "$spacemacs_init" ]; then
          if [ ! -L "$spacemacs_init" ]; then
            echo "Refusing to activate Spacemacs because $spacemacs_init exists and is not managed by Home Manager." >&2
            exit 1
          fi

          case "$(readlink "$spacemacs_init")" in
            (/nix/store/*-home-manager-files/.emacs.d/init.el) ;;
            (*)
              echo "Refusing to activate Spacemacs because $spacemacs_init is not managed by Home Manager." >&2
              exit 1
              ;;
          esac
        fi
      '';

      file.".emacs.d/init.el".text = ''
        ;; Managed by Home Manager. Personal Spacemacs settings belong in
        ;; ~/.spacemacs or ~/.spacemacs.d, both of which are intentionally
        ;; left user-owned.

        (setq spacemacs-start-directory "${inputs.spacemacs}/")
        (load-file (expand-file-name "init.el" spacemacs-start-directory))
      '';
    };

    programs.emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
    };
  };
}
