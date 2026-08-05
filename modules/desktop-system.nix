{ config, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local) keyboard;
in
{
  config.local.nixos.modules.host =
    { pkgs, ... }:
    let
      kernelPackages = pkgs.linuxPackages_latest;
      time-zone = null;
    in
    {
      hardware = {
        bluetooth.enable = true;
        graphics = {
          enable = true;
          enable32Bit = true;
        };
        nvidia = {
          modesetting.enable = true;
          nvidiaSettings = true;
          open = false; # true;
          package = kernelPackages.nvidiaPackages.latest;
          powerManagement = {
            enable = true;
            finegrained = true;
          };
          prime = {
            offload = {
              enable = true;
              enableOffloadCmd = true;
            };
            intelBusId = "PCI:0:2:0";
            nvidiaBusId = "PCI:1:0:0";
          };
        };
      };

      security = {
        polkit.enable = true;
        rtkit.enable = true;
      };

      services = {
        asusd.enable = true;
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
          publish = {
            enable = true;
            addresses = true;
            workstation = true;
            userServices = true;
          };
        };
        libinput = {
          enable = true;
          touchpad = {
            clickMethod = "clickfinger";
            disableWhileTyping = true;
            naturalScrolling = true;
            tapping = false;
          };
        };
        logind = {
          enable = true;
          settings.Login = {
            HandleLidSwitchExternalPower = "ignore";
            HandleLidSwitchDocked = "ignore";
          };
        };
        openssh = {
          enable = true;
          openFirewall = true;
        };
        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          wireplumber.enable = true;
        };
        supergfxd = {
          enable = true;
          settings = {
            always_reboot = false;
            hotplug_type = "None";
            logout_timeout_s = 180;
            mode = "Hybrid";
            no_logind = false;
            vfio_enable = false;
            vfio_save = false;
          };
        };
        udev = {
          enable = true;
          packages = with pkgs; [ sane-airscan ];
        };
        udisks2.enable = true;
        upower.enable = true;
        usbmuxd.enable = true;
        xserver = {
          enable = false;
          xkb = keyboard;
        };
      }
      // (if isNull time-zone then { automatic-timezoned.enable = true; } else { });

      systemd.services.supergfxd.path = [ pkgs.pciutils ];

      time = if isNull time-zone then { } else { timeZone = time-zone; };
    };
}
