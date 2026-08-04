{ config, ... }:

let
  inherit (config.local) stateVersion;
in
{
  config.local.nixos.modules.host =
    { pkgs, ... }:
    let
      kernelPackages = pkgs.linuxPackages_latest;
      # linux-version-drv = stdenvNoCC.mkDerivation {
      #   dontBuild = true;
      #   dontConfigure = true;
      #   installPhase = ''
      #     set -euxo pipefail
      #     export VERSION="$(cat Makefile | grep '^VERSION ' | head -n 1 | cut -d '=' -f 2- | xargs)"
      #     export PATCHLEVEL="$(cat Makefile | grep '^PATCHLEVEL ' | head -n 1 | cut -d '=' -f 2- | xargs)"
      #     export SUBLEVEL="$(cat Makefile | grep '^SUBLEVEL ' | head -n 1 | cut -d '=' -f 2- | xargs)"
      #     export EXTRAVERSION="$(cat Makefile | grep '^EXTRAVERSION ' | head -n 1 | cut -d '=' -f 2- | xargs)"
      #     export NAME="$(cat Makefile | grep '^NAME ' | head -n 1 | cut -d '=' -f 2- | xargs)"
      #     mkdir $out
      #     echo -n "''${VERSION}.''${PATCHLEVEL}.''${SUBLEVEL}" > $out/version
      #     if [ ! -z "''${EXTRAVERSION}" ]
      #     then
      #         echo -n "''${EXTRAVERSION}" >> $out/version
      #     fi
      #     echo -n "''${NAME}" > $out/aka
      #   '';
      #   name = "linux-version";
      #   src = inputs.linux-src;
      # };
      # linux-version = builtins.readFile "${linux-version-drv}/version";
      # linux-aka = builtins.readFile "${linux-version-drv}/aka";
      # linux = pkgs.buildLinux {
      #   extraMeta.branch = "master";
      #   ignoreConfigErrors = true;
      #   modDirVersion = builtins.trace "Living dangerously on Linux master@v${linux-version} a.k.a. ${linux-aka}" linux-version;
      #   src = inputs.linux-src;
      #   version = linux-version;
      # };
      # kernelPackages = lib.recurseIntoAttrs (pkgs.linuxPackagesFor linux);
    in
    {
      boot = {
        inherit kernelPackages;
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
