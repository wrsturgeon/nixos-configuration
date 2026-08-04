{ config, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local) hostName;
in
{
  config.local.nixos.modules.host = { config, lib, ... }: {
    networking = {
      inherit hostName;
      firewall = {
        enable = true;
        logRefusedPackets = true;
      };
      networkmanager =
        let
          inherit (config.age) secrets;
          secret-filenames = builtins.attrNames secrets;
          wifi-secret-filenames = builtins.filter (lib.strings.hasPrefix "wifi-") secret-filenames;
          wifi-secret-names = map (lib.strings.removePrefix "wifi-") wifi-secret-filenames;
        in
        {
          enable = true;
          ensureProfiles = {
            environmentFiles = map (name: config.age.secrets.${name}.path) wifi-secret-filenames;
            profiles = builtins.listToAttrs (
              map (name: {
                # inherit name;
                name = "\$${name}_ssid";
                value = {
                  connection = {
                    id = "\$${name}_ssid";
                    permissions = "";
                    type = "wifi";
                  };
                  ipv4.method = "auto";
                  ipv6 = {
                    addr-gen-mode = "stable-privacy";
                    method = "auto";
                  };
                  wifi = {
                    mode = "infrastructure";
                    ssid = "\$${name}_ssid";
                  };
                  wifi-security = {
                    key-mgmt = "wpa-psk";
                    psk = "\$${name}_psk";
                    psk-flags = 0;
                  };
                };
              }) wifi-secret-names
            );
          };
          logLevel = "INFO"; # "TRACE";
        };
      nftables.enable = true;
    };

  };
}
