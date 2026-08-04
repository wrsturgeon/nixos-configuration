{ config, inputs, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local)
    default-font
    default-monospace-font
    default-serif-font
    home
    location
    username
    ;
in
{
  config.local = {
    home-manager.users.${username} =
      {
        lib,
        osConfig,
        pkgs,
        ...
      }:
      let
        caelestia-wallpaper = inputs.desktop-background;
        theme = flakeConfig.local.mkTheme pkgs;
        desktopTheme = theme.active;
        hyprlandPackage = osConfig.programs.hyprland.package;
        terminalTheme = theme.defaultTerminalTheme;
        terminalThemeEditorLua = pkgs.writeText "caelestia-terminal-theme-nvim.lua" terminalTheme.editor.lua;
        terminalThemeWeztermLua = pkgs.writeText "caelestia-terminal-theme-wezterm.lua" terminalTheme.weztermRuntimeLua;
        taskPackageArgs = { inherit pkgs hyprlandPackage; };
        taskDashboard = flakeConfig.local.taskwarrior.packages.taskDashboard taskPackageArgs;
        taskReadyCount = flakeConfig.local.taskwarrior.packages.taskReadyCount taskPackageArgs;
        caelestiaResourceActiveWindow = ../caelestia-resource-active-window.qml;
        caelestiaWorkspaces = ../caelestia-workspaces.qml;
        caelestiaWorkspace = ../caelestia-workspace.qml;
        caelestiaActiveIndicator = ../caelestia-active-indicator.qml;
        caelestiaTasks = pkgs.writeText "caelestia-tasks.qml" ''
          pragma ComponentBehavior: Bound

          import QtQuick
          import Quickshell
          import Quickshell.Io
          import Caelestia.Config
          import qs.components
          import qs.services

          StyledRect {
              id: root

              property int count
              readonly property color colour: count > 0 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant

              implicitWidth: Tokens.sizes.bar.innerWidth
              implicitHeight: layout.implicitHeight + Tokens.padding.small * 2

              color: Qt.alpha(Colours.tPalette.m3surfaceContainer, count > 0 ? Colours.tPalette.m3surfaceContainer.a : 0)
              radius: Tokens.rounding.full

              function refresh(): void {
                  countProc.running = true;
              }

              StateLayer {
                  anchors.fill: parent
                  radius: root.radius
                  onClicked: Quickshell.execDetached(["${taskDashboard}/bin/task-dashboard"])
              }

              Column {
                  id: layout

                  anchors.centerIn: parent
                  spacing: Tokens.spacing.small

                  MaterialIcon {
                      anchors.horizontalCenter: parent.horizontalCenter

                      text: "task_alt"
                      color: root.colour
                  }

                  StyledText {
                      anchors.horizontalCenter: parent.horizontalCenter

                      horizontalAlignment: StyledText.AlignHCenter
                      text: root.count.toString()
                      font.pointSize: Tokens.font.size.smaller
                      font.family: Tokens.font.family.mono
                      color: root.colour
                  }
              }

              Timer {
                  interval: 30000
                  running: true
                  repeat: true
                  triggeredOnStart: true
                  onTriggered: root.refresh()
              }

              Process {
                  id: countProc

                  command: ["${taskReadyCount}/bin/task-ready-count"]
                  stdout: StdioCollector {
                      onStreamFinished: {
                          const parsed = parseInt(text.trim(), 10);
                          root.count = isNaN(parsed) ? 0 : parsed;
                      }
                  }
              }
          }
        '';
        caelestiaShellWithResources =
          (inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli.override {
            hyprland = hyprlandPackage;
          }).overrideAttrs
            (old: {
              postPatch = (old.postPatch or "") + ''
                grep -q 'roleValue: "activeWindow"' modules/bar/Bar.qml
                grep -q 'ActiveWindow {' modules/bar/Bar.qml
                grep -q 'roleValue: "clock"' modules/bar/Bar.qml
                test -f modules/bar/components/ActiveWindow.qml
                grep -q 'model: Config.bar.workspaces.shown' modules/bar/components/workspaces/Workspaces.qml
                grep -q 'const label = Config.bar.workspaces.label || displayName;' modules/bar/components/workspaces/Workspace.qml
                grep -q 'i % Config.bar.workspaces.shown' modules/bar/components/workspaces/ActiveIndicator.qml
                substituteInPlace modules/bar/Bar.qml \
                  --replace-fail '                roleValue: "clock"' '                roleValue: "tasks"
                      delegate: EntryWrapper {
                          visible: !root.fullscreen
                          Tasks {}
                      }
                  }
                  DelegateChoice {
                      roleValue: "clock"'
                cp ${caelestiaResourceActiveWindow} modules/bar/components/ActiveWindow.qml
                cp ${caelestiaWorkspaces} modules/bar/components/workspaces/Workspaces.qml
                cp ${caelestiaWorkspace} modules/bar/components/workspaces/Workspace.qml
                cp ${caelestiaActiveIndicator} modules/bar/components/workspaces/ActiveIndicator.qml
                cp ${caelestiaTasks} modules/bar/components/Tasks.qml
              '';
            });
      in
      {
        imports = [ inputs.caelestia-shell.homeManagerModules.default ];

        home = {
          file = {
            ".local/state/caelestia/wallpaper/current" = {
              force = true;
              source = caelestia-wallpaper;
            };
            ".local/state/caelestia/wallpaper/path.txt" = {
              force = true;
              text = "${caelestia-wallpaper}\n";
            };
            ".local/state/caelestia/scheme.json" = {
              force = true;
              text = builtins.toJSON desktopTheme.caelestiaScheme;
            };
          };
          activation.initializeCaelestiaTerminalTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            state_dir=${lib.escapeShellArg "${home}/.local/state/caelestia/theme"}
            mkdir -p "$state_dir"

            for theme_file in "$state_dir/nvim.lua" "$state_dir/wezterm.lua"; do
              if [ -L "$theme_file" ]; then
                rm -f "$theme_file"
              fi
            done

            ${
              if theme.terminalTheme == null then
                ''
                  if [ ! -e "$state_dir/nvim.lua" ]; then
                    cat ${terminalThemeEditorLua} > "$state_dir/nvim.lua"
                  fi

                  if [ ! -e "$state_dir/wezterm.lua" ]; then
                    cat ${terminalThemeWeztermLua} > "$state_dir/wezterm.lua"
                  fi
                ''
              else
                ''
                  cat ${terminalThemeEditorLua} > "$state_dir/nvim.lua"

                  cat ${terminalThemeWeztermLua} > "$state_dir/wezterm.lua"
                ''
            }
          '';
        };

        programs.caelestia = {
          enable = true;
          package = caelestiaShellWithResources;
          cli.enable = true;
          cli.package =
            theme.patchCaelestiaCli
              inputs.caelestia-shell.inputs.caelestia-cli.packages.${pkgs.stdenv.hostPlatform.system}.caelestia-cli;
          cli.settings.theme = {
            enableTerm = false;
            postHook = theme.runtimeThemeHook;
          };
          settings = {
            # https://github.com/caelestia-dots/shell#example-configuration
            appearance = {
              anim.durations.scale = 0.1;
              deformScale = 0.5;
              font = {
                body.family = default-font;
                clock = "${default-monospace-font} Light";
                headline.family = default-serif-font;
                label.family = default-serif-font;
                mono.family = default-monospace-font;
                title.family = default-serif-font;
              };
              rounding.scale = 0.5;
            };
            bar = {
              activeWindow.showOnHover = false;
              clock.showDate = true;
              entries = [
                {
                  id = "logo";
                  enabled = true;
                }
                {
                  id = "workspaces";
                  enabled = true;
                }
                {
                  id = "spacer";
                  enabled = true;
                }
                {
                  id = "activeWindow";
                  enabled = true;
                }
                {
                  id = "tray";
                  enabled = true;
                }
                {
                  id = "tasks";
                  enabled = true;
                }
                {
                  id = "clock";
                  enabled = true;
                }
                {
                  id = "statusIcons";
                  enabled = true;
                }
                {
                  id = "power";
                  enabled = true;
                }
              ];
            };
            border = {
              rounding = 8;
              thickness = 0;
            };
            dashboard.resourceUpdateInterval = 500;
            general.idle.timeouts = [ ];
            launcher = {
              showOnHover = true;
              vimKeybinds = true;
            };
            services = {
              useFahrenheit = true;
              useTwelveHourClock = false;
              inherit (location) weatherLocation;
            };
            session.vimKeybinds = true;
          };
        };
      };

    nixos.modules.host =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        inherit (pkgs.stdenv.hostPlatform) system;
        theme = flakeConfig.local.mkTheme pkgs;
        desktopTheme = theme.active;
        caelestiaCli =
          theme.patchCaelestiaCli
            inputs.caelestia-shell.inputs.caelestia-cli.packages.${system}.caelestia-cli;
      in
      {
        systemd.user.services.night-shift = {
          environment = {
            CAELESTIA_SCHEME_NAME = desktopTheme.schemeName;
            CAELESTIA_SCHEME_FLAVOUR = desktopTheme.flavour;
            CAELESTIA_SCHEME_VARIANT = desktopTheme.caelestiaScheme.variant;
          };
          path = [
            (pkgs.python3.withPackages (pythonPackages: [ pythonPackages.astral ]))
            caelestiaCli
            config.programs.hyprland.package
            pkgs.brightnessctl
            pkgs.dconf
          ];
          script = ''
            python ${../night-shift.py} \
              --latitude ${lib.escapeShellArg location.latitude} \
              --longitude ${lib.escapeShellArg location.longitude}
          '';
          startAt = "minutely";
        };
      };
  };
}
