{ pkgs, ... }:
let
  piApplyPatch = pkgs.callPackage ./apply-patch/package.nix { };
  piTempDir = pkgs.callPackage ./tempdir/package.nix { };
  piRunPython = pkgs.callPackage ./run-python/package.nix { nixpkgsPath = pkgs.path; };
  piReplaceAll = pkgs.callPackage ./replace-all/package.nix { };

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
}
