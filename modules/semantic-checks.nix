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
      spacemacsInit = userConfig.home.file.".emacs.d/init.el".text;
      spacemacsUserConfig = userConfig.home.file.".spacemacs.d/init.el";
      spacemacsInitText = builtins.unsafeDiscardStringContext spacemacsInit;

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
        assert require "WezTerm is enabled for the primary Home Manager user"
          userConfig.programs.wezterm.enable;
        assert require "Caelestia is enabled for the primary Home Manager user"
          userConfig.programs.caelestia.enable;
        assert require "Emacs is enabled for the primary Home Manager user"
          userConfig.programs.emacs.enable;
        assert require "Emacs uses the pure GTK package" (
          userConfig.programs.emacs.package.pname == "emacs-pgtk"
        );
        assert require "EDITOR uses Emacs" (hostConfig.environment.variables.EDITOR == "emacs");
        assert require "Spacemacs loader points at the writable source copy" (
          pkgs.lib.hasInfix "~/.emacs.d/spacemacs-source/" spacemacsInitText
        );
        assert require "Spacemacs loader uses ~/.spacemacs.d" (
          pkgs.lib.hasInfix "SPACEMACSDIR" spacemacsInitText
        );
        assert require "Spacemacs user config is checked into the flake" (
          builtins.pathExists spacemacsUserConfig.source
        );
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
            emacs = userConfig.programs.emacs.enable;
            wezterm = userConfig.programs.wezterm.enable;
          };
          emacsPackage = userConfig.programs.emacs.package.pname;
          editor = hostConfig.environment.variables.EDITOR;
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
