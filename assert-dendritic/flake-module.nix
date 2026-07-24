{ lib, self, ... }:
let
  name = "assert-dendritic";
in
{
  options.${name} = {
    moduleRoot = lib.mkOption {
      type = lib.types.path;
      default = "${self.outPath}/modules";
      defaultText = lib.literalExpression ''"${self.outPath}/modules"'';
      description = ''
        If you use `import-tree`, this is the argument `p` in `(import-tree p)`.
        In plain English, this is the directory under which all your module files live.
      '';
    };
  };

  config.perSystem = _perSystemInputs: { checks.${name} = import ./mk-check.nix self; };
}
