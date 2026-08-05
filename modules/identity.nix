{ lib, ... }:

let
  hostName = "ENIAC";
  username = "will";
  nh-os-flags = "-L --bypass-root-check";
in
{
  options.local = {
    default-font = lib.mkOption {
      type = lib.types.str;
      description = "Default sans-serif UI font family.";
    };

    default-monospace-font = lib.mkOption {
      type = lib.types.str;
      description = "Default monospace font family.";
    };

    default-serif-font = lib.mkOption {
      type = lib.types.str;
      description = "Default serif UI font family.";
    };

    github-username = lib.mkOption {
      type = lib.types.str;
      description = "GitHub account used by Git, Bugwarrior, and automation.";
    };

    home = lib.mkOption {
      type = lib.types.str;
      description = "Home directory for the primary user.";
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      description = "NixOS host name.";
    };

    keyboard = lib.mkOption {
      type = lib.types.submodule {
        options = {
          layout = lib.mkOption { type = lib.types.str; };
          options = lib.mkOption { type = lib.types.str; };
          variant = lib.mkOption { type = lib.types.str; };
        };
      };
      description = "Keyboard layout settings shared by NixOS, Home Manager, and Hyprland.";
    };

    location = lib.mkOption {
      type = lib.types.submodule {
        options = {
          latitude = lib.mkOption { type = lib.types.str; };
          longitude = lib.mkOption { type = lib.types.str; };
          weatherLocation = lib.mkOption { type = lib.types.str; };
        };
      };
      description = "Physical location used by weather and night-shift services.";
    };

    nh-clean-all-flags = lib.mkOption {
      type = lib.types.str;
      description = "Flags passed to nh clean.";
    };

    nh-os-flags = lib.mkOption {
      type = lib.types.str;
      description = "Flags passed to nh os commands.";
    };

    nrs = lib.mkOption {
      type = lib.types.str;
      description = "Canonical nh command for switching this NixOS host.";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      description = "Shared NixOS and Home Manager state version.";
    };

    unfree-regex = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Regular expressions for permitted unfree package names.";
    };

    username = lib.mkOption {
      type = lib.types.str;
      description = "Primary user name.";
    };
  };

  config.local = {
    inherit hostName nh-os-flags username;

    default-font = "Spline Sans SS02";
    default-monospace-font = "Iosevka Custom";
    default-serif-font = "Test Martina Plantijn";
    github-username = "wrsturgeon";
    home = "/home/${username}";
    nh-clean-all-flags = "--keep-since 24h --optimise";
    nrs = "nh os switch /etc/nixos -H ${lib.strings.escapeShellArg hostName} ${nh-os-flags}";
    stateVersion = "25.05";

    keyboard = {
      layout = "us";
      options = "caps:swapescape";
      variant = "";
    };

    location =
      let
        # SF:
        latitude = "37.8";
        longitude = "-122.4";
        # NYC:
        # latitude = "40.7";
        # longitude = "-74.0";
      in
      {
        inherit latitude longitude;
        weatherLocation = "${latitude},${longitude}";
      };

    unfree-regex = [
      "aspell-dict-.*"
      "cud.*"
      "libcu.*"
      "libnpp"
      "libnv.*"
      "nvidia-.*"
      "spotify"
    ];
  };
}
