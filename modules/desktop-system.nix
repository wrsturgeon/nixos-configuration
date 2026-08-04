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

      # Graphics & desktop:
      services = builtins.mapAttrs (_k: v: { enable = true; } // v) (
        {
          asusd = { };
          avahi = {
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
            touchpad = {
              clickMethod = "clickfinger";
              disableWhileTyping = true;
              naturalScrolling = true;
              tapping = false;
            };
          };
          logind.settings.Login = {
            # HandleLidSwitch = "ignore";
            HandleLidSwitchExternalPower = "ignore";
            HandleLidSwitchDocked = "ignore";
          };
          openssh = {
            openFirewall = true;
          };
          pipewire = {
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
            wireplumber.enable = true;
          };
          supergfxd.settings = {
            always_reboot = false;
            hotplug_type = "None";
            logout_timeout_s = 180;
            mode = "Hybrid";
            no_logind = false;
            vfio_enable = false;
            vfio_save = false;
          };
          tlp.settings = {
            CPU_ENERGY_PERF_POLICY_ON_AC = if isNull time-zone then "performance" else "power";
            CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
            CPU_ENERGY_PERF_POLICY_ON_SAV = "power";
            PLATFORM_PROFILE_ON_AC = if isNull time-zone then "performance" else "power";
            PLATFORM_PROFILE_ON_BAT = "quiet";
            PLATFORM_PROFILE_ON_SAV = "quiet";
          };
          udev.packages = with pkgs; [ sane-airscan ];
          udisks2 = { };
          upower = { };
          usbmuxd = { };
          xserver = {
            enable = false;
            xkb = keyboard;
          };
        }
        // (if isNull time-zone then { automatic-timezoned = { }; } else { })
      );

      systemd.services.supergfxd.path = [ pkgs.pciutils ];

      time = if isNull time-zone then { } else { timeZone = time-zone; };
    };
}
