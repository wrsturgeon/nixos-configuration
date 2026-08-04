{
  config,
  inputs,
  lib,
  ...
}:

let
  flakeConfig = config;
in
{
  options.local.home-manager.users = lib.mkOption {
    type = lib.types.attrsOf lib.types.deferredModule;
    default = { };
    description = "Home Manager user modules keyed by user name.";
  };

  config.local.nixos.modules.host = {
    imports = [ inputs.home-manager.nixosModules.home-manager ];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users = builtins.mapAttrs (_username: module: {
        imports = [ module ];
      }) flakeConfig.local.home-manager.users;
    };
  };
}
