{ config, ... }:

let
  inherit (config.local) stateVersion;
in
{
  config.local.nixos.modules.host = { pkgs, ... }: {
    boot = {
      kernelPackages = pkgs.linuxPackages_latest;
      loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
      tmp.cleanOnBoot = true;
    };

    console = {
      earlySetup = true;
      font = "${pkgs.terminus_font}/share/consolefonts/ter-u12n.psf.gz";
      useXkbConfig = true;
    };

    i18n.defaultLocale = "en_US.UTF-8";

    swapDevices = [
      {
        device = "/swapfile";
        size = 256 * 1024; # 1024=1GiB
      }
    ];

    system = { inherit stateVersion; };
  };
}
