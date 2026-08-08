{ lib, ... }:

{
  options.local.desktop = lib.mkOption {
    type = lib.types.enum [
      "ewm"
      "hyprland"
      "tty"
    ];
    description = "Complete graphical desktop profile selected for this host.";
  };
}
