{ config, inputs, ... }:

let
  inherit (config.local) username;
in
{
  config.local.home-manager.users.${username} = { pkgs, ... }: {
    home.packages = with pkgs; [
      bash-language-server
      element-desktop
      haskell-language-server
      legcord
      libreoffice-qt6
      # logseq
      luajitPackages.lua-lsp
      nixd
      ocamlPackages.ocaml-lsp
      pyright
      rust-analyzer
      spotify
      super-productivity
      tor-browser
      wayneko
      yaml-language-server
      yazi
      zls
      zulip
    ];

    imports = [ inputs.zen-browser.homeModules.twilight ];

    programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
      btop = { };
      gh = {
        gitCredentialHelper.enable = false;
        settings = {
          git_protocol = "https";
          prompt = "enabled";
        };
      };
      home-manager = { };
      htop = { };
      opencode = {
        settings = {
          "$schema" = "https://opencode.ai/config.json";
          agent.build = {
            mode = "primary";
            tools."*" = true;
          };
          permission = {
            bash = "allow";
            edit = "allow";
            glob = "allow";
            grep = "allow";
            list = "allow";
            lsp = "allow";
            question = "allow";
            read = "allow";
            skill = "allow";
            todoread = "allow";
            todowrite = "allow";
            webfetch = "allow";
            websearch = "allow";
          };
        };
        tui.theme = "system";
      };
      zen-browser = {
        setAsDefaultBrowser = true;
        policies.Preferences."browser.tabs.unloadOnLowMemory" = {
          Value = true;
          Status = "user";
        };
      };
    };

    services = builtins.mapAttrs (_k: v: { enable = true; } // v) {
      hyprpolkitagent = { };
      hyprsunset = { };
      poweralertd = { };
      spotifyd.settings.global.bitrate = 320;
    };
  };
}
