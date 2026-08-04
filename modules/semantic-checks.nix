{
  config,
  inputs,
  self,
  ...
}:

let
  flakeConfig = config;
in
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };

      hostConfig = self.nixosConfigurations.${flakeConfig.local.hostName}.config;
      userConfig = hostConfig.home-manager.users.${flakeConfig.local.username};
      theme = flakeConfig.local.theme.forPkgs pkgs;

      themeNames = map (theme: theme.name) theme.allThemes;
      themeColourKeySets = map (theme: builtins.attrNames theme.caelestiaScheme.colours) theme.allThemes;
      firstThemeColourKeySet = builtins.head themeColourKeySets;

      require =
        description: condition: if condition then true else throw "semantic check failed: ${description}";

      report =
        assert require "host config uses local.hostName" (
          hostConfig.networking.hostName == flakeConfig.local.hostName
        );
        assert require "host config uses local.stateVersion" (
          hostConfig.system.stateVersion == flakeConfig.local.stateVersion
        );
        assert require "NixVim is enabled" hostConfig.programs.nixvim.enable;
        assert require "WezTerm is enabled for the primary Home Manager user"
          userConfig.programs.wezterm.enable;
        assert require "Caelestia is enabled for the primary Home Manager user"
          userConfig.programs.caelestia.enable;
        assert require "systemd-coredump does not store cores" (
          hostConfig.systemd.coredump.settings.Coredump.Storage == "none"
        );
        assert require "systemd-coredump skips core processing" (
          hostConfig.systemd.coredump.settings.Coredump.ProcessSizeMax == "0"
        );
        assert require "the theme catalogue is non-empty" (theme.allThemes != [ ]);
        assert require "all Caelestia themes expose the same colour keys" (
          pkgs.lib.all (keys: keys == firstThemeColourKeySet) themeColourKeySets
        );
        {
          hostName = hostConfig.networking.hostName;
          stateVersion = hostConfig.system.stateVersion;
          coredump = hostConfig.systemd.coredump.settings.Coredump;
          homeManagerUser = flakeConfig.local.username;
          enabled = {
            caelestia = userConfig.programs.caelestia.enable;
            nixvim = hostConfig.programs.nixvim.enable;
            wezterm = userConfig.programs.wezterm.enable;
          };
          theme = {
            inherit (theme) activeFamily;
            names = themeNames;
            colourKeyCount = builtins.length firstThemeColourKeySet;
          };
        };

      reportJson = pkgs.writeText "nixos-semantic-checks.json" (builtins.toJSON report);
    in
    {
      checks.nixos-semantics = pkgs.runCommand "nixos-semantic-checks" { } ''
        mkdir "$out"
        cp ${reportJson} "$out/report.json"
      '';
    };
}
