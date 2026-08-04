{ inputs, ... }:

let
  glazeFor =
    system:
    let
      pkgs = import inputs.nixpkgs { inherit system; };
    in
    pkgs.glaze.overrideAttrs (_oldAttrs: {
      version = "7.2.0";
      src = pkgs.fetchFromGitHub {
        owner = "stephenberry";
        repo = "glaze";
        tag = "v7.2.0";
        hash = "sha256-f3NVRi3SXKo42hn0WCw7JsOK3EkdOVJIcuzhPorKjFY=";
      };
    });

  hyprlandFor =
    system:
    (inputs.hyprland.packages.${system}.hyprland.override { enableXWayland = false; }).overrideAttrs
      (oldAttrs: {
        buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ (glazeFor system) ];
      });

  hyprlandPortalFor =
    system:
    inputs.hyprland.packages.${system}.xdg-desktop-portal-hyprland.override {
      hyprland = hyprlandFor system;
    };

  hyprlandOverlay = final: _prev: {
    hyprland = hyprlandFor final.stdenv.hostPlatform.system;
    xdg-desktop-portal-hyprland = hyprlandPortalFor final.stdenv.hostPlatform.system;
  };
in
{
  config.local.nixos.modules.host =
    { config, pkgs, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) system;
      hyprlandPackage = hyprlandFor system;
      hyprlandPortalPackage = hyprlandPortalFor system;
    in
    {
      imports = [ inputs.hyprland.nixosModules.default ];

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
}
