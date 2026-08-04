{ config, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local)
    github-username
    nh-os-flags
    nrs
    username
    ;
  rebuild-nixos-service-name = "rebuild-nixos";
in
{
  config.local.nixos.modules.host = { config, pkgs, ... }: {
    systemd = {
      coredump.settings.Coredump = {
        # systemd-coredump can turn crash loops into huge bursts of disk I/O.
        # Keep the journal event, but skip storing or processing the core itself.
        Storage = "none";
        ProcessSizeMax = "0";
      };

      services = {
        journal-gc = {
          path = with pkgs; [ systemd ];
          script = ''
            shopt -s nullglob
            set -euxo pipefail

            journalctl --vacuum-time=2d
          '';
          serviceConfig.User = "root";
          startAt = "*-*-* 04:00:00";
        };
        build-artifact-gc = {
          path = with pkgs; [
            coreutils
            findutils
          ];
          script = ''
            shopt -s nullglob
            set -euxo pipefail

            roots=(
              /home/${username}/Desktop/Code
              /home/${username}/pbt
                                 )

            existing_roots=()
            for root in "''${roots[@]}"; do
              if [ -e "$root" ]; then
                existing_roots+=("$root")
              fi
            done

            if [ "''${#existing_roots[@]}" -eq 0 ]; then
              exit 0
            fi

            find "''${existing_roots[@]}" -xdev -mindepth 1 \
              \( -path /home/${username}/.cache -o -path /home/${username}/.local/share/Trash -o -path /root/.cache \) -prune -o \
              \( -type d \( -name target -o -name _build -o -name .lake -o -name .direnv \) -prune -print -exec rm -rf -- {} + \) -o \
              \( -type f -name 'vgcore.*' -print -exec rm -f -- {} + \)
          '';
          serviceConfig = {
            Type = "oneshot";
            User = "root";
          };
          startAt = "*-*-* 04:00:00";
        };
        nix-index = {
          script = ''
            shopt -s nullglob
            set -euxo pipefail

            nix run nixpkgs#nix-index
          '';
          serviceConfig.User = username;
          startAt = "*-*-* 04:00:00";
        };
        nix-index-root = {
          script = ''
            shopt -s nullglob
            set -euxo pipefail

            nix run nixpkgs#nix-index
          '';
          serviceConfig.User = "root";
          startAt = "*-*-* 04:00:00";
        };
        ${rebuild-nixos-service-name} = {
          restartIfChanged = false;
          stopIfChanged = false;

          path = with pkgs; [
            gh
            git
            gnupg
            nh
            nix
            nixos-rebuild
            openssh
            pmutils
            su
            systemd
          ];
          script = ''
            shopt -s nullglob
            set -euo pipefail

            export GH_TOKEN="$(cat ${config.age.secrets.gh-pat.path})"
            export GITHUB_TOKEN="$GH_TOKEN"
            export GIT_TERMINAL_PROMPT=0

            set -x

            if on_ac_power; then
                echo 'Computer is plugged in; continuing...'
            else
                echo 'Computer is not plugged in; aborting...'
                exit
            fi

            cd /etc/nixos
            nix flake update
            nix fmt

            nh os boot . ${nh-os-flags} --cores=1 # --max-jobs=1

            git add -A
            git commit -m 'Automatic build succeeded' || :
            git push -u "https://github.com/${github-username}/nixos-configuration.git" main
            ${nrs} --keep-going --no-nom
          '';
          serviceConfig = {
            User = "root";

            Nice = 19;
            CPUSchedulingPolicy = "idle";
            IOSchedulingClass = "idle";

            CPUWeight = "idle";
            IOWeight = 1;

            MemoryHigh = "50%";
            MemoryMax = "75%";

            OOMPolicy = "stop";
          };
          startAt = "hourly"; # "*-*-* 04:00:00";
        };
      };

      slices.user.sliceConfig.MemoryLow = "25%";

      timers.build-artifact-gc.timerConfig.Persistent = true;

      user.services.aura-keyboard = {
        description = "Keyboard backlight on login.";
        script =
          # "asusctl aura effect static --colour ffffff";
          "asusctl aura effect rainbow-wave --direction right --speed low";
        wantedBy = [ "multi-user.target" ]; # starts after login
      };
    };

  };
}
