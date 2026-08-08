{ config, lib, ... }:

let
  inherit (config.local) home stateVersion username;
  piHomeModule =
    { pkgs, ... }:
    let
      piApplyPatch = pkgs.callPackage ../pi/apply-patch/package.pkg.nix { };
      piElisp = pkgs.callPackage ../pi/elisp/package.pkg.nix {
        emacsHome = home;
        emacsUser = username;
      };
      piTempDir = pkgs.callPackage ../pi/tempdir/package.pkg.nix { };
      piRunPython = pkgs.callPackage ../pi/run-python/package.pkg.nix { nixpkgsPath = pkgs.path; };
      piReplaceAll = pkgs.callPackage ../pi/replace-all/package.pkg.nix { };

      enlightenmentPrompt = ../worse-is-better-monologue.md;
    in
    {
      home.file = {
        ".pi/agent/AGENTS.md" = {
          force = true;
          text = builtins.readFile enlightenmentPrompt;
        };
        ".pi/agent/extensions/apply-patch" = {
          force = true;
          source = piApplyPatch;
        };
        ".pi/agent/extensions/elisp" = {
          force = true;
          source = piElisp;
        };
        ".pi/agent/extensions/tempdir" = {
          force = true;
          source = piTempDir;
        };
        ".pi/agent/extensions/run-python" = {
          force = true;
          source = piRunPython;
        };
        ".pi/agent/extensions/replace-all" = {
          force = true;
          source = piReplaceAll;
        };
        ".pi/agent/prompts/enlightenment.md" = {
          force = true;
          text = builtins.readFile enlightenmentPrompt;
        };
      };
    };
in
{
  options.local.home-manager.modules.pi = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = "Reusable Home Manager module that installs Pi agent files.";
  };

  config.local.home-manager = {
    modules.pi = piHomeModule;
    users.root = {
      imports = [ piHomeModule ];
      home = {
        inherit stateVersion;
        homeDirectory = "/root";
        username = "root";
      };
    };
  };
}
