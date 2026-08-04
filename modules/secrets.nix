{ config, inputs, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local) username;
in
{
  config.local.nixos.modules.host = { lib, ... }: {
    imports = [ inputs.agenix.nixosModules.default ];

    age.secrets =
      let
        generatedSecrets = builtins.mapAttrs (_: file: { inherit file; }) (
          let
            filetypes = builtins.readDir ../secrets;
            ls = builtins.attrNames filetypes;
            ages = builtins.filter (lib.strings.hasSuffix ".age") ls;
          in
          builtins.listToAttrs (
            map (f: {
              name = lib.strings.removeSuffix ".age" f;
              value = ../secrets/${f};
            }) ages
          )
        );
      in
      generatedSecrets
      // {
        gh-pat = generatedSecrets.gh-pat // {
          owner = username;
        };
        logseq-api-token = generatedSecrets.logseq-api-token // {
          owner = username;
        };
      };

  };
}
