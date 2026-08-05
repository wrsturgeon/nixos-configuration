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
        spacemacs_source="$emacs_dir/spacemacs-source"
        spacemacs_store=${lib.escapeShellArg "${inputs.spacemacs}"}
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

        if [ -e "$spacemacs_source" ] && [ ! -f "$spacemacs_source/.nix-source" ]; then
          echo "Refusing to replace unmanaged Spacemacs source at $spacemacs_source." >&2
          echo "Move it aside first if Home Manager should manage that directory." >&2
          exit 1
        fi

        if [ ! -e "$spacemacs_source" ] || [ "$(cat "$spacemacs_source/.nix-source")" != "$spacemacs_store" ]; then
          rm -rf "$spacemacs_source"
          mkdir -p "$spacemacs_source"
          cp -R "$spacemacs_store"/. "$spacemacs_source"/
          echo "$spacemacs_store" > "$spacemacs_source/.nix-source"
          chmod -R u+rwX "$spacemacs_source"
        fi

        if [ ! -w "$spacemacs_source" ]; then
          echo "Refusing to activate Spacemacs because $spacemacs_source is not writable." >&2
          exit 1
        fi
      '';

      file = {
        ".emacs.d/init.el" = {
          force = true;
          text = ''
            ;; Managed by Home Manager. Personal Spacemacs settings belong in
            ;; ~/.spacemacs.d/init.el, which is checked into this NixOS flake.

            (setenv "SPACEMACSDIR" (expand-file-name "~/.spacemacs.d/"))
            (setq spacemacs-start-directory (expand-file-name "~/.emacs.d/spacemacs-source/"))
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

    services.emacs = {
      defaultEditor = true;
      enable = true;
      startWithUserSession = true;
    };
  };
}
