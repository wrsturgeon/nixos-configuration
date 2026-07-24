{
  outputs = _: {
    # `__functor` makes an attrset callable:
    # https://nix.dev/manual/nix/2.27/language/syntax.html#attribute-set
    # https://releases.nixos.org/nix/nix-2.33.3/manual/language/operators.html#function-application
    __functor = _flake: _moduleArgs: {
      # `flake-parts` evaluates flake modules with module class "flake":
      # https://github.com/hercules-ci/flake-parts/blob/main/lib.nix
      _class = "flake";
      imports = [ ./flake-module.nix ];
    };
  };
}
