{ config, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local) home username;
in
{
  config.local.nixos.modules.host = { config, pkgs, ... }: {
    users = {
      users.${username} = {
        inherit home;
        extraGroups = [
          "audio"
          "dialout" # USB
          "lp" # printing (& scanning?) documents
          "networkmanager"
          "scanner" # scanning documents
          "wheel" # `sudo`
        ];
        hashedPasswordFile = config.age.secrets.passwd.path;
        isNormalUser = true;
        shell = pkgs.zsh;
      };
    };
  };
}
