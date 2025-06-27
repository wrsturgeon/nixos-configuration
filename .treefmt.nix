{ pkgs, ... }:
{
  programs =
    builtins.mapAttrs
      (_: package: {
        inherit package;
        enable = true;
      })
      {
        inherit (pkgs) mdformat;
        nixfmt = pkgs.nixfmt-rfc-style;
      };
  projectRootFile = "flake.nix";
}
