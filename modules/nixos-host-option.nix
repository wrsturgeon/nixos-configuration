{ lib, ... }:

{
  options.local.nixos.modules.host = lib.mkOption {
    type = lib.types.deferredModule;
    default = { };
    description = "Merged NixOS module for the configured host.";
  };
}
