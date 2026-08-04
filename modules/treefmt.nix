{ inputs, self, ... }:

let
  treefmtModule = _: {
    programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
      deadnix = { };
      keep-sorted = { };
      nixfmt.strict = true;
      qmlformat = { };
      statix = { };
    };
    projectRootFile = "flake.nix";
    settings.formatter = {
      deadnix.priority = 1;
      statix.priority = 2;
      keep-sorted.priority = 3;
      nixfmt.priority = 4;
    };
  };
in
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs treefmtModule;
    in
    {
      checks.style = treefmt.config.build.check self;
      formatter = treefmt.config.build.wrapper;
    };
}
