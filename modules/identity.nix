{ lib, ... }:

let
  hostName = "ENIAC";
  username = "will";
  nh-os-flags = "-L --bypass-root-check";
in
{
  config.local = {
    inherit hostName nh-os-flags username;

    default-font = "Spline Sans SS02";
    default-monospace-font = "Iosevka Custom";
    default-serif-font = "Test Martina Plantijn";
    github-username = "wrsturgeon";
    home = "/home/${username}";
    nh-clean-all-flags = "--keep-since 24h --optimise";
    nrs = "nh os switch /etc/nixos -H ${lib.strings.escapeShellArg hostName} ${nh-os-flags}";
    stateVersion = "25.05";

    keyboard = {
      layout = "us";
      options = "caps:swapescape";
      variant = "";
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
  };
}
