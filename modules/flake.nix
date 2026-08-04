{ config, inputs, ... }:

let
  flakeConfig = config;
in
{
  imports = [ inputs.assert-dendritic ];

  systems = [ "x86_64-linux" ];

  flake.nixosConfigurations.${flakeConfig.local.hostName} = inputs.nixpkgs.lib.nixosSystem {
    modules = [ flakeConfig.local.nixos.modules.host ];
  };

  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
    in
    {
      apps = builtins.mapAttrs (name: command: {
        program = "${pkgs.writeShellScriptBin name ''
          shopt -s nullglob
          set -euxo pipefail

          ${command}
        ''}/bin/${name}";
        type = "app";
      }) { default = flakeConfig.local.nrs; };
    };
}
