{ inputs, ... }:

let
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
