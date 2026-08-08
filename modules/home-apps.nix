{ config, inputs, ... }:

let
  flakeConfig = config;
  inherit (config.local) username;
in
{
  config.local.home-manager.users.${username} = { pkgs, ... }: {
    # Use `environment.systemPackages` instead of `home.packages`
    # for anything except e.g. desktop GUI applications:
    # as a rule of thumb, anything that *might* be useful as root,
    # even e.g. editing `/etc/nixos` in Emacs, ought to be available as root.
    home.packages = with pkgs; [
      element-desktop
      legcord
      libreoffice-qt6
      spotify
      tor-browser
      wayneko
      zulip
    ];

    imports = [ inputs.zen-browser.homeModules.twilight ];

    programs = {
      btop.enable = true;
      gh = {
        enable = true;
        gitCredentialHelper.enable = false;
        settings = {
          git_protocol = "https";
          prompt = "enabled";
        };
      };
      home-manager.enable = true;
      htop.enable = true;
      opencode = {
        enable = true;
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
        enable = true;
        setAsDefaultBrowser = true;
        policies.Preferences."browser.tabs.unloadOnLowMemory" = {
          Value = true;
          Status = "user";
        };
      };
    };

    services = {
      hyprpolkitagent.enable = flakeConfig.local.desktop == "hyprland";
      hyprsunset.enable = flakeConfig.local.desktop == "hyprland";
      poweralertd.enable = true;
      spotifyd = {
        enable = true;
        settings.global.bitrate = 320;
      };
    };
  };
}
