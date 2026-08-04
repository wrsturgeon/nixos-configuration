{ config, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local)
    default-font
    default-monospace-font
    default-serif-font
    home
    username
    ;
in
{
  config.local.home-manager.users.${username} =
    { lib, pkgs, ... }:
    let
      theme = flakeConfig.local.theme.forPkgs pkgs;
      desktopThemes = theme.themeFamilies.${theme.activeFamily};
      logseqCss = pkgs.writeText "logseq-custom.css" ''
        :root {
          color-scheme: light;
        }

        ${desktopThemes.light.logseqCss}

        @media (prefers-color-scheme: dark) {
        :root {
          color-scheme: dark;
        }

        ${desktopThemes.dark.logseqCss}
        }

        :root {
          --ls-font-family: "${default-font}", Inter, sans-serif;
        }

        .inline,
        .block-editor {
          font-family: "${default-font}", Inter, sans-serif;
        }

        .CodeMirror {
          font-family: "${default-monospace-font}", monospace;
        }

        .left-sidebar-inner {
          font-family: "${default-font}", Inter, sans-serif;
        }

        h1.title,
        h1.title input,
        .title {
          font-family: "${default-serif-font}", "Source Serif 4", serif;
          font-weight: 600;
        }

        :not(pre)>code {
          font-family: "${default-monospace-font}", monospace;
        }
      '';
    in
    {
      home.activation.writeLogseqCustomCss = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target=${lib.escapeShellArg "${home}/Logseq/logseq/custom.css"}
        if [ -L "$target" ]; then
          rm -f "$target"
        fi
        install -Dm0644 ${logseqCss} "$target"
        chmod u+w "$target"
      '';
    };

  config.local.nixos.modules.host = { pkgs, ... }: {
    systemd.services.logseq = {
      path = with pkgs; [ git ];
      script = ''
        shopt -s nullglob
        set -euxo pipefail

        cd ~/Logseq
        git add -A
        git commit --no-gpg-sign -m 'Automatic commit'
        git push
      '';
      serviceConfig.User = username;
      startAt = "minutely";
    };
  };
}
