args@{
  default-font,
  default-serif-font,
  default-monospace-font,
  github-username,
  home,
  inputs,
  lib,
  location,
  pkgs,
  stateVersion,
  username,
  ...
}:
let

  caelestia-wallpaper = inputs.desktop-background;
  theme = import ./theme.nix {
    caelestiaCliSrc = inputs.caelestia-shell.inputs.caelestia-cli.outPath;
    inherit lib pkgs;
    inherit (inputs) onedark zed-one;
  };
  desktopTheme = theme.active;
  desktopThemes = theme.themeFamilies.${theme.activeFamily};
  bugwarriorGithubToken = "/run/agenix/gh-pat";
  bugwarriorGmailClientSecret = "${home}/.config/bugwarrior/gmail-client-secret.json";
  bugwarriorGmailCredentials = "${taskDataLocation}/gmail_credentials_gmail.pickle";
  bugwarriorLogseqToken = "${home}/.config/bugwarrior/logseq-token";
  bugwarriorPackage = pkgs.python313.withPackages (
    pythonPackages:
    [ pythonPackages.bugwarrior ] ++ pythonPackages.bugwarrior.optional-dependencies.gmail
  );
  hyprlandPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  taskDataLocation = "${home}/.local/share/task";
  terminalTheme = theme.defaultTerminalTheme;
  terminalThemeEditorLua = pkgs.writeText "caelestia-terminal-theme-nvim.lua" terminalTheme.editor.lua;
  terminalThemeWeztermLua = pkgs.writeText "caelestia-terminal-theme-wezterm.lua" terminalTheme.weztermRuntimeLua;
  taskReadyCount = pkgs.writeShellApplication {
    name = "task-ready-count";
    runtimeInputs = [ pkgs.taskwarrior3 ];
    text = ''
      task rc.verbose=nothing status:pending scheduled.before:now count
    '';
  };
  taskDashboard = pkgs.writeShellApplication {
    name = "task-dashboard";
    runtimeInputs = [
      hyprlandPackage
      pkgs.jq
      pkgs.taskwarrior-tui
      pkgs.wezterm
    ];
    text = ''
      mode=toggle
      case "''${1:-}" in
        ("")
          ;;
        (--show)
          mode=show
          ;;
        (--toggle)
          ;;
        (*)
          echo "usage: task-dashboard [--show|--toggle]" >&2
          exit 64
          ;;
      esac

      dashboard_exists() {
        hyprctl clients -j | jq -e 'any(.[]; .class == "taskwarrior-tui")' >/dev/null
      }

      dashboard_visible() {
        hyprctl monitors -j | jq -e 'any(.[]; .specialWorkspace.name == "special:tasks")' >/dev/null
      }

      show_dashboard() {
        dashboard_visible || hyprctl dispatch "hl.dsp.workspace.toggle_special('tasks')"
      }

      if ! dashboard_exists; then
        show_dashboard
        hyprctl dispatch "hl.dsp.exec_cmd('wezterm start --always-new-process --class taskwarrior-tui -- taskwarrior-tui')"
        exit 0
      fi

      if [ "$mode" = show ]; then
        show_dashboard
      else
        hyprctl dispatch "hl.dsp.workspace.toggle_special('tasks')"
      fi
    '';
  };
  taskCapture = pkgs.writeShellApplication {
    name = "task-capture";
    runtimeInputs = [
      pkgs.fuzzel
      pkgs.libnotify
      pkgs.python3
      pkgs.taskwarrior3
    ];
    text = ''
      entry="$(
        fuzzel \
          --dmenu \
          --prompt-only="task add " \
          --placeholder="dentist scheduled:18:00 +health" \
          --width=72 \
          || true
      )"

      if [ -z "''${entry//[[:space:]]/}" ]; then
        exit 0
      fi

      python3 - "$entry" <<'PY'
      import shlex
      import subprocess
      import sys

      entry = sys.argv[1].strip()

      try:
          args = shlex.split(entry)
      except ValueError as exc:
          subprocess.run(
              [
                  "notify-send",
                  "-a",
                  "Taskwarrior",
                  "-u",
                  "critical",
                  "Task capture failed",
                  str(exc),
              ],
              check=False,
          )
          raise SystemExit(2) from exc

      if not args:
          raise SystemExit(0)

      completed = subprocess.run(
          ["task", "add", *args],
          text=True,
          stdout=subprocess.PIPE,
          stderr=subprocess.PIPE,
          check=False,
      )

      if completed.returncode != 0:
          message = (completed.stderr or completed.stdout).strip()
          subprocess.run(
              [
                  "notify-send",
                  "-a",
                  "Taskwarrior",
                  "-u",
                  "critical",
                  "Task capture failed",
                  message or "task add exited without an error message",
              ],
              check=False,
          )
          raise SystemExit(completed.returncode)

      subprocess.run(
          [
              "notify-send",
              "-a",
              "Taskwarrior",
              "-i",
              "view-task",
              "Task captured",
              entry,
          ],
          check=False,
      )
      PY
    '';
  };
  taskReminderNotify = pkgs.writeShellApplication {
    name = "task-reminder-notify";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.python3
      pkgs.taskwarrior3
    ];
    text = ''
      if [ "$#" -ne 1 ]; then
        echo "usage: task-reminder-notify UUID" >&2
        exit 64
      fi

      python3 - "$1" "${taskDashboard}/bin/task-dashboard" <<'PY'
      import json
      import re
      import subprocess
      import sys

      uuid = sys.argv[1]
      dashboard = sys.argv[2]

      if re.fullmatch(r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}", uuid) is None:
          raise SystemExit(f"invalid Taskwarrior UUID: {uuid}")

      export = subprocess.run(
          [
              "task",
              "rc.verbose=nothing",
              uuid,
              "status:pending",
              "scheduled.before:now",
              "export",
          ],
          text=True,
          stdout=subprocess.PIPE,
          stderr=subprocess.PIPE,
          check=False,
      )

      if export.returncode != 0:
          raise SystemExit(export.stderr.strip() or export.returncode)

      tasks = json.loads(export.stdout or "[]")
      if not tasks:
          raise SystemExit(0)

      task = tasks[0]
      body = task["description"]
      if project := task.get("project"):
          body += f"\nProject: {project}"
      if due := task.get("due"):
          body += f"\nDue: {due}"
      if scheduled := task.get("scheduled"):
          body += f"\nScheduled: {scheduled}"

      action = subprocess.run(
          [
              "notify-send",
              "-a",
              "Taskwarrior",
              "-i",
              "view-task",
              "-u",
              "normal",
              "-A",
              "done=Done",
              "-A",
              "open=Open",
              "--wait",
              "Task reminder",
              body,
          ],
          text=True,
          stdout=subprocess.PIPE,
          stderr=subprocess.DEVNULL,
          check=False,
      ).stdout.strip()

      if action == "done":
          subprocess.run(
              ["task", "rc.confirmation=off", uuid, "done"],
              check=False,
          )
      elif action == "open":
          subprocess.Popen(
              [dashboard, "--show"],
              stdout=subprocess.DEVNULL,
              stderr=subprocess.DEVNULL,
              start_new_session=True,
          )
      PY
    '';
  };
  taskReminders = pkgs.writeShellApplication {
    name = "task-reminders";
    runtimeInputs = [
      pkgs.python3
      pkgs.systemd
      pkgs.taskwarrior3
    ];
    text = ''
      python3 - <<'PY'
      import json
      import subprocess

      export = subprocess.run(
          [
              "task",
              "rc.verbose=nothing",
              "status:pending",
              "scheduled.before:now",
              "export",
          ],
          text=True,
          stdout=subprocess.PIPE,
          stderr=subprocess.PIPE,
          check=False,
      )

      if export.returncode != 0:
          raise SystemExit(export.stderr.strip() or export.returncode)

      for task in json.loads(export.stdout or "[]"):
          uuid = task.get("uuid")
          if not uuid:
              continue
          unit = subprocess.run(
              [
                  "systemd-escape",
                  "--template=task-reminder-notify@.service",
                  uuid,
              ],
              text=True,
              stdout=subprocess.PIPE,
              check=True,
          ).stdout.strip()
          subprocess.run(["systemctl", "--user", "start", unit], check=False)
      PY
    '';
  };
  bugwarriorPull = pkgs.writeShellApplication {
    name = "bugwarrior-pull-local";
    runtimeInputs = [
      bugwarriorPackage
      pkgs.coreutils
      pkgs.taskwarrior3
    ];
    text = ''
      mode=pull
      case "''${1:-}" in
        ("")
          ;;
        (--authorize-gmail)
          mode=authorize-gmail
          ;;
        (*)
          echo "usage: bugwarrior-pull-local [--authorize-gmail]" >&2
          exit 64
          ;;
      esac

      require_file() {
        path="$1"
        description="$2"
        if [ ! -s "$path" ]; then
          echo "Missing $description: $path" >&2
          return 1
        fi
      }

      require_file ${lib.escapeShellArg bugwarriorGmailClientSecret} "Gmail OAuth client secret"

      if [ "$mode" = authorize-gmail ]; then
        exec bugwarrior pull --flavor gmail-auth --dry-run --debug
      fi

      require_file ${lib.escapeShellArg bugwarriorGithubToken} "GitHub token"
      require_file ${lib.escapeShellArg bugwarriorGmailCredentials} "Gmail OAuth credentials"
      if ! require_file ${lib.escapeShellArg bugwarriorLogseqToken} "Logseq API token"; then
        {
          echo "Enable Logseq's HTTP APIs server, create an authorization token, and write it to that file."
        } >&2
        exit 1
      fi

      exec bugwarrior pull --quiet
    '';
  };
  caelestiaResourceActiveWindow = ./caelestia-resource-active-window.qml;
  caelestiaWorkspaces = ./caelestia-workspaces.qml;
  caelestiaWorkspace = ./caelestia-workspace.qml;
  caelestiaActiveIndicator = ./caelestia-active-indicator.qml;
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
    inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli.overrideAttrs
      (old: {
        postPatch = (old.postPatch or "") + ''
          grep -q 'roleValue: "activeWindow"' modules/bar/Bar.qml
          grep -q 'sourceComponent: ActiveWindow' modules/bar/Bar.qml
          grep -q 'roleValue: "clock"' modules/bar/Bar.qml
          test -f modules/bar/components/ActiveWindow.qml
          grep -q 'model: Config.bar.workspaces.shown' modules/bar/components/workspaces/Workspaces.qml
          grep -q 'const label = Config.bar.workspaces.label || displayName;' modules/bar/components/workspaces/Workspace.qml
          grep -q 'i % Config.bar.workspaces.shown' modules/bar/components/workspaces/ActiveIndicator.qml
          substituteInPlace modules/bar/Bar.qml \
            --replace-fail '                roleValue: "clock"' '                roleValue: "tasks"
                delegate: WrappedLoader {
                    visible: !root.fullscreen
                    sourceComponent: Tasks {}
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
      bugwarriorPackage
      bugwarriorPull
      discord
      element-desktop # matrix
      haskell-language-server
      libreoffice-qt6
      logseq
      luajitPackages.lua-lsp
      mailspring
      nixd
      ocamlPackages.ocaml-lsp
      pyright
      rust-analyzer
      spotify
      super-productivity
      taskCapture
      taskDashboard
      taskReadyCount
      taskReminderNotify
      taskReminders
      taskwarrior-tui
      tor-browser
      wayneko
      yaml-language-server
      zls
      zulip
    ];
    file = {
      ".agents/skills/enlightenment.md" = {
        force = true;
        text = builtins.readFile ./worse-is-better-monologue.md;
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
    ./pi/home-manager.nix
    inputs.caelestia-shell.homeManagerModules.default
    inputs.zen-browser.homeModules.twilight
  ];

  programs = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    btop = { };
    codex = {
      package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex;
      settings = { };
      skills.enlightenment = builtins.readFile ./worse-is-better-monologue.md;
    };
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
          anim.durations.scale = 0.0; # 0.5;
          deformScale = 0.5;
          font.family = {
            clock = "${default-monospace-font} Light";
            mono = default-monospace-font;
            sans = default-font;
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
          status = {
            showAudio = true;
            showKbLayout = true;
            showMicrophone = true;
          };
        };
        border = {
          rounding = 8;
          thickness = 0;
        };
        dashboard.resourceUpdateInterval = 500;
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
    taskwarrior = {
      package = pkgs.taskwarrior3;
      dataLocation = taskDataLocation;
      config = {
        confirmation = false;
        uda = {
          githubbody = {
            type = "string";
            label = "Github Body";
          };
          githubclosedon = {
            type = "date";
            label = "GitHub Closed";
          };
          githubcreatedon = {
            type = "date";
            label = "Github Created";
          };
          githubdraft = {
            type = "numeric";
            label = "GitHub Draft";
          };
          githubmilestone = {
            type = "string";
            label = "Github Milestone";
          };
          githubnamespace = {
            type = "string";
            label = "Github Namespace";
          };
          githubnumber = {
            type = "numeric";
            label = "Github Issue/PR #";
          };
          githubrepo = {
            type = "string";
            label = "Github Repo Slug";
          };
          githubstate = {
            type = "string";
            label = "GitHub State";
          };
          githubtitle = {
            type = "string";
            label = "Github Title";
          };
          githubtype = {
            type = "string";
            label = "Github Type";
          };
          githubupdatedat = {
            type = "date";
            label = "Github Updated";
          };
          githuburl = {
            type = "string";
            label = "Github URL";
          };
          githubuser = {
            type = "string";
            label = "Github User";
          };
          gmaillabels = {
            type = "string";
            label = "GMail labels";
          };
          gmaillastmessageid = {
            type = "string";
            label = "Last RFC2822 Message-ID";
          };
          gmaillastsender = {
            type = "string";
            label = "GMail last sender name";
          };
          gmaillastsenderaddr = {
            type = "string";
            label = "GMail last sender address";
          };
          gmailsnippet = {
            type = "string";
            label = "GMail snippet";
          };
          gmailsubject = {
            type = "string";
            label = "GMail Subject";
          };
          gmailthreadid = {
            type = "string";
            label = "GMail Thread Id";
          };
          gmailurl = {
            type = "string";
            label = "GMail URL";
          };
          logseqdeadline = {
            type = "date";
            label = "Logseq Deadline";
          };
          logseqdone = {
            type = "date";
            label = "Logseq Done";
          };
          logseqid = {
            type = "string";
            label = "Logseq ID";
          };
          logseqpage = {
            type = "string";
            label = "Logseq Page";
          };
          logseqscheduled = {
            type = "date";
            label = "Logseq Scheduled";
          };
          logseqstate = {
            type = "string";
            label = "Logseq State";
          };
          logseqtitle = {
            type = "string";
            label = "Logseq Title";
          };
          logsequri = {
            type = "string";
            label = "Logseq URI";
          };
          logsequuid = {
            type = "string";
            label = "Logseq UUID";
          };
        };
      };
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

        ${builtins.readFile ./wezterm.lua}

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
    zen-browser.setAsDefaultBrowser = true;
  };

  xdg.configFile."bugwarrior/bugwarrior.toml".text = ''
    [general]
    targets = ["logseq", "github", "gmail"]
    taskrc = "${home}/.config/task/taskrc"
    inline_links = false
    description_length = 200

    [flavor.gmail-auth]
    targets = ["gmail"]
    taskrc = "${home}/.config/task/taskrc"
    inline_links = false
    description_length = 200

    [logseq]
    service = "logseq"
    token = "@oracle:eval:cat ${bugwarriorLogseqToken}"
    import_labels_as_tags = true
    add_tags = ["logseq"]

    [github]
    service = "github"
    login = "${github-username}"
    username = "${github-username}"
    token = "@oracle:eval:cat ${bugwarriorGithubToken}"
    query = "assignee:${github-username} is:open"
    include_user_repos = false
    include_user_issues = false
    import_labels_as_tags = true
    label_template = "github_{{label}}"
    add_tags = ["github"]
    project_owner_prefix = true
    body_length = 2000
    description_template = "GH {{githubrepo}}#{{githubnumber}} {{githubtitle}}"

    [gmail]
    service = "gmail"
    client_secret_path = "${bugwarriorGmailClientSecret}"
    query = "label:taskwarrior"
    login_name = "me"
    thread_limit = 100
    add_tags = ["gmail"]
    project_template = "gmail"
    description_template = "Email: {{gmailsubject}}"
  '';

  services = builtins.mapAttrs (_k: v: { enable = true; } // v) {
    hyprpolkitagent = { };
    hyprsunset = { };
    poweralertd = { };
    spotifyd.settings.global.bitrate = 320;
  };

  systemd.user = {
    services = {
      bugwarrior-pull = {
        Unit.Description = "Pull external Bugwarrior tasks into Taskwarrior";
        Service = {
          Type = "oneshot";
          ExecStart = "${bugwarriorPull}/bin/bugwarrior-pull-local";
        };
      };
      task-reminders = {
        Unit.Description = "Scan Taskwarrior for scheduled reminders";
        Service = {
          Type = "oneshot";
          ExecStart = "${taskReminders}/bin/task-reminders";
        };
      };
      "task-reminder-notify@" = {
        Unit.Description = "Show Taskwarrior reminder notification for %I";
        Service = {
          Type = "exec";
          ExecStart = "${taskReminderNotify}/bin/task-reminder-notify %I";
        };
      };
    };
    timers = {
      bugwarrior-pull = {
        Unit.Description = "Pull external Bugwarrior tasks into Taskwarrior every five minutes";
        Timer = {
          OnBootSec = "1min";
          OnUnitActiveSec = "5min";
          Unit = "bugwarrior-pull.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
      task-reminders = {
        Unit.Description = "Scan Taskwarrior for scheduled reminders every minute";
        Timer = {
          OnBootSec = "30s";
          OnUnitActiveSec = "1min";
          Unit = "task-reminders.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };

  wayland.windowManager.hyprland = {
    configType = "lua";
    enable = true;
    package = null;
    portalPackage = null;
    settings = import ./hyprland.nix (args // { inherit taskCapture taskDashboard; });
    systemd.variables = [ "--all" ];
  };
}
