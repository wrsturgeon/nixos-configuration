{ config, inputs, ... }:

let
  inherit (config.local) home username;
in
{
  config.local.home-manager.users.${username} = { lib, pkgs, ... }: {
    home = {
      activation.prepareSpacemacsState = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        emacs_file=${lib.escapeShellArg "${home}/.emacs"}
        spacemacs_file=${lib.escapeShellArg "${home}/.spacemacs"}
        emacs_dir=${lib.escapeShellArg "${home}/.emacs.d"}
        spacemacs_dir=${lib.escapeShellArg "${home}/.spacemacs.d"}

        require_real_writable_dir() {
          dir="$1"

          if [ -L "$dir" ]; then
            echo "Refusing to activate Spacemacs because $dir is a symlink." >&2
            echo "Spacemacs needs a real writable directory there for package and cache state." >&2
            exit 1
          fi

          if [ -e "$dir" ] && [ ! -d "$dir" ]; then
            echo "Refusing to activate Spacemacs because $dir exists and is not a directory." >&2
            exit 1
          fi

          mkdir -p "$dir"
          chmod u+rwx "$dir"

          if [ ! -w "$dir" ]; then
            echo "Refusing to activate Spacemacs because $dir is not writable." >&2
            exit 1
          fi
        }

        if [ -e "$emacs_file" ] || [ -L "$emacs_file" ]; then
          echo "Refusing to activate Spacemacs because $emacs_file exists." >&2
          echo "Move it aside first; Emacs loads ~/.emacs before ~/.emacs.d/init.el." >&2
          exit 1
        fi

        if [ -e "$spacemacs_file" ] || [ -L "$spacemacs_file" ]; then
          echo "Refusing to activate Spacemacs because $spacemacs_file exists." >&2
          echo "This configuration uses ~/.spacemacs.d/init.el instead." >&2
          exit 1
        fi

        require_real_writable_dir "$emacs_dir"
        require_real_writable_dir "$spacemacs_dir"

        mkdir -p \
          "$emacs_dir/elpa" \
          "$emacs_dir/.cache" \
          "$emacs_dir/private" \
          "$emacs_dir/eln-cache"
      '';

      file = {
        ".emacs.d/init.el" = {
          force = true;
          text = ''
            ;; Managed by Home Manager. Personal Spacemacs settings belong in
            ;; ~/.spacemacs.d/init.el, which is checked into this NixOS flake.

            (setenv "SPACEMACSDIR" (expand-file-name "~/.spacemacs.d/"))
            (setq spacemacs-start-directory "${inputs.spacemacs}/")
            (load-file (expand-file-name "init.el" spacemacs-start-directory))
          '';
        };

        ".spacemacs.d/init.el" = {
          force = true;
          source = ../spacemacs.el;
        };
      };
    };

    programs.emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
    };
  };
}
