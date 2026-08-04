{ lib, ... }:

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

    mkGoogleFonts = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      description = "Build the pinned Google Fonts package for a package set.";
    };

    mkHyprlandSettings = lib.mkOption {
      type = lib.types.functionTo lib.types.attrs;
      description = "Build the Caelestia Hyprland settings attrset for a Home Manager module.";
    };

    mkTheme = lib.mkOption {
      type = lib.types.functionTo lib.types.attrs;
      description = "Build the shared desktop theme values for a package set.";
    };

    nh-clean-all-flags = lib.mkOption {
      type = lib.types.str;
      description = "Flags passed to nh clean.";
    };

    nh-os-flags = lib.mkOption {
      type = lib.types.str;
      description = "Flags passed to nh os commands.";
    };

    nixos.modules.host = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = "Merged NixOS module for the configured host.";
    };

    home-manager.modules.pi = lib.mkOption {
      type = lib.types.deferredModule;
      default = { };
      description = "Reusable Home Manager module that installs Pi agent files.";
    };

    home-manager.users = lib.mkOption {
      type = lib.types.attrsOf lib.types.deferredModule;
      default = { };
      description = "Home Manager user modules keyed by user name.";
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
}
