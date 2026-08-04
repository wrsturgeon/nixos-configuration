{ config, inputs, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local)
    default-font
    default-monospace-font
    default-serif-font
    home
    location
    stateVersion
    username
    ;
in
{
  config.local.home-manager.users.${username} =
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
      desktopThemes = theme.themeFamilies.${theme.activeFamily};
      hyprlandPackage = osConfig.programs.hyprland.package;
      terminalTheme = theme.defaultTerminalTheme;
      terminalThemeEditorLua = pkgs.writeText "caelestia-terminal-theme-nvim.lua" terminalTheme.editor.lua;
      terminalThemeWeztermLua = pkgs.writeText "caelestia-terminal-theme-wezterm.lua" terminalTheme.weztermRuntimeLua;
      coredumpCrashNotify = pkgs.writeShellApplication {
        name = "coredump-crash-notify";
        runtimeInputs = [
          pkgs.libnotify
          pkgs.python3
          pkgs.systemd
        ];
        text = ''
          python3 - <<'PY'
          import json
          import os
          import pathlib
          import subprocess
          import time

          message_id = "fc2e22bc6ee647b6b90729ab34a250b1"  # systemd SD_MESSAGE_COREDUMP
          window = "15 minutes ago"
          threshold = 3
          cooldown_seconds = 15 * 60

          journal = subprocess.run(
              [
                  "journalctl",
                  f"MESSAGE_ID={message_id}",
                  "--since",
                  window,
                  "--output=json",
                  "--no-pager",
              ],
              text=True,
              stdout=subprocess.PIPE,
              stderr=subprocess.PIPE,
              check=False,
          )

          if journal.returncode != 0:
              raise SystemExit(journal.stderr.strip() or journal.returncode)

          crashes = {}
          for line in journal.stdout.splitlines():
              entry = json.loads(line)
              executable = entry.get("COREDUMP_EXE") or entry.get("COREDUMP_COMM") or "unknown executable"
              process = entry.get("COREDUMP_COMM") or pathlib.Path(executable).name
              signal = entry.get("COREDUMP_SIGNAL_NAME") or entry.get("COREDUMP_SIGNAL") or "unknown signal"
              crashes.setdefault(executable, {"process": process, "signal": signal, "count": 0})
              crashes[executable]["count"] += 1
              crashes[executable]["signal"] = signal

          offenders = [
              (executable, details)
              for executable, details in crashes.items()
              if details["count"] >= threshold
          ]
          if not offenders:
              raise SystemExit(0)

          state_home = pathlib.Path(os.environ.get("XDG_STATE_HOME", pathlib.Path.home() / ".local/state"))
          state_dir = state_home / "coredump-crash-notify"
          state_dir.mkdir(parents=True, exist_ok=True)
          state_file = state_dir / "last-notified.json"

          try:
              last_notified = json.loads(state_file.read_text())
          except FileNotFoundError:
              last_notified = {}

          now = time.time()
          due = [
              (executable, details)
              for executable, details in sorted(offenders, key=lambda item: item[1]["count"], reverse=True)
              if now - float(last_notified.get(executable, 0)) >= cooldown_seconds
          ]
          if not due:
              raise SystemExit(0)

          lines = [
              f"{details['process']}: {details['count']} crashes in the last 15 minutes ({details['signal']})\n{executable}"
              for executable, details in due[:5]
          ]
          subprocess.run(
              [
                  "notify-send",
                  "--app-name=Coredump Watch",
                  "--urgency=critical",
                  "Crash loop detected",
                  "\n\n".join(lines),
              ],
              check=False,
          )

          for executable, _details in due:
              last_notified[executable] = now
          state_file.write_text(json.dumps(last_notified, sort_keys=True))
          PY
        '';
      };
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
      logseqCss = pkgs.writeText "logseq-custom.css" ''
        :root {
          color-scheme: light;
        }

        ${desktopThemes.light.logseqCss}

        @media (prefers-color-scheme: dark) {
        :root {
          color-scheme: dark;
        }

        ${desktopThemes.dark.logseqCss}
        }

        :root {
          --ls-font-family: "${default-font}", Inter, sans-serif;
        }

        .inline,
        .block-editor {
          font-family: "${default-font}", Inter, sans-serif;
        }

        .CodeMirror {
          font-family: "${default-monospace-font}", monospace;
        }

        .left-sidebar-inner {
          font-family: "${default-font}", Inter, sans-serif;
        }

        h1.title,
        h1.title input,
        .title {
          font-family: "${default-serif-font}", "Source Serif 4", serif;
          font-weight: 600;
        }

        :not(pre)>code {
          font-family: "${default-monospace-font}", monospace;
        }
      '';
    in
    {
      gtk = {
        enable = true;
        font.name = default-font;
      };
      home = {
        inherit stateVersion username;
        packages = with pkgs; [
          bash-language-server
          element-desktop
          haskell-language-server
          legcord
          libreoffice-qt6
          # logseq
          luajitPackages.lua-lsp
          nixd
          ocamlPackages.ocaml-lsp
          pyright
          rust-analyzer
          spotify
          super-productivity
          tor-browser
          wayneko
          yaml-language-server
          yazi
          zls
          zulip
        ];
        file = {
          ".agents/skills/enlightenment.md" = {
            force = true;
            text = builtins.readFile ../worse-is-better-monologue.md;
          };
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
        activation.writeLogseqCustomCss = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          target=${lib.escapeShellArg "${home}/Logseq/logseq/custom.css"}
          if [ -L "$target" ]; then
            rm -f "$target"
          fi
          install -Dm0644 ${logseqCss} "$target"
          chmod u+w "$target"
        '';
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
        pointerCursor = {
          enable = true;
          hyprcursor.enable = true;
          package = pkgs.rose-pine-hyprcursor;
          name = "cursor";
        };
        homeDirectory = home;
      };

      imports = [
        flakeConfig.local.home-manager.modules.pi
        inputs.caelestia-shell.homeManagerModules.default
        inputs.zen-browser.homeModules.twilight
      ];

      programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
        btop = { };
        gh = {
          gitCredentialHelper.enable = false;
          settings = {
            git_protocol = "https";
            prompt = "enabled";
          };
        };
        home-manager = { };
        htop = { };
        caelestia = {
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
        opencode = {
          settings = {
            "$schema" = "https://opencode.ai/config.json";
            agent.build = {
              mode = "primary";
              tools."*" = true;
            };
            permission = {
              bash = "allow";
              edit = "allow";
              glob = "allow";
              grep = "allow";
              list = "allow";
              lsp = "allow";
              question = "allow";
              read = "allow";
              skill = "allow";
              todoread = "allow";
              todowrite = "allow";
              webfetch = "allow";
              websearch = "allow";
            };
          };
          tui.theme = "system";
        };
        wezterm = {
          enableBashIntegration = true;
          enableZshIntegration = true;
          extraConfig = ''
            local wezterm = require 'wezterm'
            local config = wezterm.config_builder()

            local state_home = os.getenv('XDG_STATE_HOME') or (wezterm.home_dir .. '/.local/state')
            local theme_path = state_home .. '/caelestia/theme/wezterm.lua'
            local ok, theme = pcall(dofile, theme_path)

            if ok and type(theme) == 'table' then
              for key, value in pairs(theme) do
                config[key] = value
              end
            else
              ${terminalTheme.weztermLua}
            end

            config.font = wezterm.font('${default-monospace-font}')

            ${builtins.readFile ../wezterm.lua}

            local function sorted_table_keys(t)
              local keys = {}
              for key, _ in pairs(t) do
                table.insert(keys, key)
              end
              table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
              end)
              return keys
            end

            local function color_key_path(prefix, key)
              if type(key) == 'number' then
                return prefix .. '[' .. key .. ']'
              end
              if prefix == "" then
                return tostring(key)
              end
              return prefix .. '.' .. tostring(key)
            end

            local function is_indexed_key(prefix, key)
              return prefix == "" and key == 'indexed'
            end

            local function first_indexed_color_keys(t)
              local filtered = {}
              for key, _ in pairs(t) do
                if type(key) == 'number' and key >= 16 and key <= 31 then
                  table.insert(filtered, key)
                end
              end
              table.sort(filtered)
              return filtered
            end

            local function collect_missing_default_color_keys(defaults, theme, prefix, missing)
              local keys = sorted_table_keys(defaults)
              if prefix == 'indexed' then
                keys = first_indexed_color_keys(defaults)
              end

              for _, key in ipairs(keys) do
                local path = color_key_path(prefix, key)
                local default_value = defaults[key]
                local theme_value = theme[key]

                if theme_value == nil then
                  table.insert(missing, path)
                elseif type(default_value) == 'table' then
                  if type(theme_value) ~= 'table' then
                    table.insert(missing, path .. '.*')
                  else
                    if is_indexed_key(prefix, key) then
                      collect_missing_default_color_keys(default_value, theme_value, 'indexed', missing)
                    else
                      collect_missing_default_color_keys(default_value, theme_value, path, missing)
                    end
                  end
                end
              end
            end

            local function collect_extraneous_color_keys(defaults, theme, prefix, extraneous)
              local keys = sorted_table_keys(theme)
              if prefix == 'indexed' then
                keys = first_indexed_color_keys(theme)
              end

              for _, key in ipairs(keys) do
                local path = color_key_path(prefix, key)
                local default_value = defaults[key]
                local theme_value = theme[key]

                if default_value == nil then
                  table.insert(extraneous, path)
                elseif type(theme_value) == 'table' then
                  if type(default_value) ~= 'table' then
                    table.insert(extraneous, path .. '.*')
                  else
                    if is_indexed_key(prefix, key) then
                      collect_extraneous_color_keys(default_value, theme_value, 'indexed', extraneous)
                    else
                      collect_extraneous_color_keys(default_value, theme_value, path, extraneous)
                    end
                  end
                end
              end
            end

            local function assert_selected_color_scheme_is_explicit()
              local scheme_name = config.color_scheme
              if scheme_name == nil then
                error('No WezTerm color_scheme is selected', 0)
              end

              local schemes = config.color_schemes or {}
              local scheme = schemes[scheme_name]
              if type(scheme) ~= 'table' then
                error('Selected WezTerm color_scheme is not defined locally: ' .. tostring(scheme_name), 0)
              end

              local defaults = wezterm.color.get_default_colors()
              local missing = {}
              collect_missing_default_color_keys(defaults, scheme, "", missing)
              local extraneous = {}
              collect_extraneous_color_keys(defaults, scheme, "", extraneous)

              local problems = {}
              if #missing > 0 then
                table.insert(
                  problems,
                  'missing explicit WezTerm color setting(s) present in wezterm.color.get_default_colors():\n  - '
                    .. table.concat(missing, '\n  - ')
                )
              end
              if #extraneous > 0 then
                table.insert(
                  problems,
                  'extraneous WezTerm color setting(s) absent from wezterm.color.get_default_colors():\n  - '
                    .. table.concat(extraneous, '\n  - ')
                )
              end

              if #problems > 0 then
                error('Theme "' .. scheme_name .. '" has invalid WezTerm color setting coverage:\n\n' .. table.concat(problems, '\n\n'), 0)
              end
            end

            assert_selected_color_scheme_is_explicit()

            return config
          '';
        };
        zen-browser = {
          setAsDefaultBrowser = true;
          policies.Preferences."browser.tabs.unloadOnLowMemory" = {
            Value = true;
            Status = "user";
          };
        };
      };

      services = builtins.mapAttrs (_k: v: { enable = true; } // v) {
        hyprpolkitagent = { };
        hyprsunset = { };
        poweralertd = { };
        spotifyd.settings.global.bitrate = 320;
      };

      systemd.user = {
        services = {
          coredump-crash-notify = {
            Unit.Description = "Notify when one executable repeatedly dumps core";
            Service = {
              Type = "oneshot";
              ExecStart = "${coredumpCrashNotify}/bin/coredump-crash-notify";
            };
          };
        };
        timers = {
          coredump-crash-notify = {
            Unit.Description = "Scan recent coredumps every minute";
            Timer = {
              OnBootSec = "1min";
              OnUnitActiveSec = "1min";
              Unit = "coredump-crash-notify.service";
            };
            Install.WantedBy = [ "timers.target" ];
          };
        };
      };

    };
}
