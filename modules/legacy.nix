{ inputs, self, ... }:
let
  inherit (inputs.nixpkgs) lib;

  hostName = "ENIAC";
  github-username = "wrsturgeon";
  username = "will";

  keyboard = {
    layout = "us";
    options = "caps:swapescape";
    variant = ""; # "colemak_dh";
  };

  location =
    let
      # SF:
      latitude = "37.8";
      longitude = "-122.4";
      # NYC:
      # latitude = "40.7";
      # longitude = "-74.0";
    in
    {
      inherit latitude longitude;
      weatherLocation = "${latitude},${longitude}";
    };

  unfree-regex = [
    "cud.*"
    "libcu.*"
    "libnpp"
    "libnv.*"
    "nvidia-.*"
    "spotify"
  ];

  hyprlandFor =
    system: inputs.hyprland.packages.${system}.hyprland.override { enableXWayland = false; };

  hyprlandPortalFor =
    system:
    inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland.override {
      hyprland = hyprlandFor system;
    };

  hyprlandOverlay = final: _prev: {
    hyprland = hyprlandFor final.stdenv.hostPlatform.system;
    xdg-desktop-portal-hyprland = hyprlandPortalFor final.stdenv.hostPlatform.system;
  };

  hyprlandModule =
    { config, pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      hyprlandPackage = hyprlandFor system;
      hyprlandPortalPackage = hyprlandPortalFor system;
    in
    {
      assertions = [
        {
          assertion = config.programs.hyprland.package.drvPath == hyprlandPackage.drvPath;
          message = "programs.hyprland.package must be the canonical no-XWayland Hyprland package.";
        }
        {
          assertion = config.programs.hyprland.portalPackage.drvPath == hyprlandPortalPackage.drvPath;
          message = "programs.hyprland.portalPackage must be paired with the canonical Hyprland package.";
        }
        {
          assertion = pkgs.hyprland.drvPath == hyprlandPackage.drvPath;
          message = "pkgs.hyprland must be the canonical no-XWayland Hyprland package.";
        }
        {
          assertion = !config.programs.hyprland.xwayland.enable;
          message = "Hyprland is intentionally hard-coded without XWayland.";
        }
      ];

      nixpkgs.overlays = [ hyprlandOverlay ];

      programs.hyprland = {
        package = hyprlandPackage;
        portalPackage = hyprlandPortalPackage;
        xwayland.enable = false;
      };
    };

  specialArgs = {
    inherit
      github-username
      hostName
      inputs
      keyboard
      location
      nh-clean-all-flags
      nh-os-flags
      nrs
      outputs
      unfree-regex
      username
      ;
    # Spline Sans with its ss02 double-decker g baked in; see spline-sans-ss02 in configuration.nix.
    default-font = "Spline Sans SS02"; # "Mallory Trial MP Narrow"; # "Taurus Grotesk Trial"; # "Bricolage Grotesque 92.5"; # "GT America 95"; # "Instrument Sans 90"; # "Inter"; # "IBM Plex Sans";
    default-monospace-font = "Iosevka Custom";
    default-serif-font = "Test Martina Plantijn";
    home = "/home/${username}";
    stateVersion = "25.05";
  };

  inherit (self) outputs;

  nh-clean-all-flags = "--keep-since 24h --optimise";
  nh-os-flags = "-L --bypass-root-check";

  home-module = {
    home-manager = {
      extraSpecialArgs = specialArgs; # what the FUCK: https://www.reddit.com/r/NixOS/comments/1bqzg78
      useGlobalPkgs = true;
      useUserPackages = true;
      # what the FUCK: https://discourse.nixos.org/t/how-to-explicity-pass-arguments-config-and-pkgs-to-home-managers-nixos-module/16607
      users = {
        ${username}.imports = [ ../home.nix ];
        root = {
          imports = [ ../pi/home-manager.nix ];
          home = {
            username = "root";
            homeDirectory = "/root";
            inherit (specialArgs) stateVersion;
          };
        };
      };
    };
  };

  nrs = "nh os switch /etc/nixos -H ${lib.strings.escapeShellArg hostName} ${nh-os-flags}";
in
{
  systems = [ "x86_64-linux" ];

  flake.nixosConfigurations.${hostName} = lib.nixosSystem {
    inherit specialArgs;
    modules = [
      ../hardware-configuration.nix
      ../nixos-hardware.nix
      ../configuration.nix
      inputs.agenix.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      home-module
      inputs.hyprland.nixosModules.default
      hyprlandModule
      inputs.nixvim.nixosModules.nixvim
    ];
  };

  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
      treefmt = inputs.treefmt-nix.lib.evalModule pkgs ../.treefmt.nix;
    in
    {
      apps = builtins.mapAttrs (k: v: {
        program = "${pkgs.writeShellScriptBin k ''
          shopt -s nullglob
          set -euxo pipefail

          ${v}
        ''}/bin/${k}";
        type = "app";
      }) { default = nrs; };

      checks.style = treefmt.config.build.check self;

      formatter = treefmt.config.build.wrapper;
    };
}
