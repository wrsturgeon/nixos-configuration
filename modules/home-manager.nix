{ config, inputs, ... }:

let
  flakeConfig = config;
in
{
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
