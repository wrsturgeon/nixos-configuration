{ config, lib, ... }:

let
  flakeConfig = config;
  inherit (flakeConfig.local) github-username home username;
in
{
  options.local.taskwarrior.packages =
    let
      packageFactory =
        description:
        lib.mkOption {
          type = lib.types.functionTo lib.types.package;
          inherit description;
        };
    in
    {
      taskCapture = packageFactory "Build the Taskwarrior capture launcher.";
      taskDashboard = packageFactory "Build the Taskwarrior dashboard launcher.";
      taskReadyCount = packageFactory "Build the Taskwarrior ready-count helper.";
      taskReminderNotify = packageFactory "Build the Taskwarrior reminder notification helper.";
      taskReminders = packageFactory "Build the Taskwarrior reminder scanner.";
    };

  config.local.taskwarrior.packages = {
    taskReadyCount =
      { pkgs, ... }:
      pkgs.writeShellApplication {
        name = "task-ready-count";
        runtimeInputs = [ pkgs.taskwarrior3 ];
        text = ''
          task rc.verbose=nothing status:pending scheduled.before:now count
        '';
      };
    taskDashboard =
      { hyprlandPackage, pkgs, ... }:
      pkgs.writeShellApplication {
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
    taskCapture =
      { pkgs, ... }:
      pkgs.writeShellApplication {
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
    taskReminderNotify =
      packageArgs@{ pkgs, ... }:
      let
        taskDashboard = flakeConfig.local.taskwarrior.packages.taskDashboard packageArgs;
      in
      pkgs.writeShellApplication {
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
    taskReminders =
      { pkgs, ... }:
      pkgs.writeShellApplication {
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
  };

  config.local.home-manager.users.${username} =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      bugwarriorGithubToken = "/run/agenix/gh-pat";
      bugwarriorLogseqToken = "/run/agenix/logseq-api-token";
      bugwarriorPython = pkgs.python313.override {
        packageOverrides = _final: prev: {
          taskw = (prev.taskw.override { taskwarrior2 = pkgs.taskwarrior3; }).overridePythonAttrs (oldAttrs: {
            # Taskwarrior 3 no longer matches this Taskwarrior-2-specific bracket
            # query test, but Bugwarrior only needs taskw's shellout add/update and
            # UDA filters, which were tested against a Taskwarrior 3 database.
            disabledTests = (oldAttrs.disabledTests or [ ]) ++ [ "test_filtering_brace" ];
          });
        };
      };
      bugwarriorPackage = bugwarriorPython.withPackages (pythonPackages: [ pythonPackages.bugwarrior ]);
      hyprlandPackage = osConfig.programs.hyprland.package;
      taskDataLocation = "${home}/.local/share/task";
      taskPackageArgs = { inherit pkgs hyprlandPackage; };
      taskPackages = builtins.mapAttrs (
        _name: mkTaskPackage: mkTaskPackage taskPackageArgs
      ) flakeConfig.local.taskwarrior.packages;
      inherit (taskPackages)
        taskCapture
        taskDashboard
        taskReadyCount
        taskReminderNotify
        taskReminders
        ;
    in
    {
      home = {
        packages = [
          bugwarriorPackage
          taskCapture
          taskDashboard
          taskReadyCount
          taskReminderNotify
          taskReminders
          pkgs.taskwarrior-tui
        ];
        activation.secureBugwarriorConfigDirectory = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          bugwarrior_config_dir=${lib.escapeShellArg "${home}/.config/bugwarrior"}
          install -d -m 0700 "$bugwarrior_config_dir"
          chmod 0700 "$bugwarrior_config_dir"
        '';
        activation.configureLogseqApi = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          secret=${lib.escapeShellArg bugwarriorLogseqToken}
          logseq_config_dir=${lib.escapeShellArg "${home}/.config/Logseq"}
          logseq_config="$logseq_config_dir/configs.edn"

          if [ ! -s "$secret" ]; then
            echo "Missing Logseq API token: $secret" >&2
            exit 1
          fi

          install -d -m 0700 "$logseq_config_dir"
          ${pkgs.python3}/bin/python3 - "$secret" "$logseq_config" <<'PY'
          import json
          import pathlib
          import sys

          secret, target = map(pathlib.Path, sys.argv[1:])
          token = secret.read_text(encoding="utf-8").strip()
          if not token:
              raise SystemExit(f"empty Logseq API token: {secret}")

          target.write_text(
              "{:window/native-titlebar? false, "
              ':server/host "127.0.0.1", '
              ":server/port 12315, "
              ":server/autostart true, "
              f':server/tokens [{{:name "bugwarrior", :value {json.dumps(token)}}}]}}\n',
              encoding="utf-8",
          )
          PY
          chmod 0600 "$logseq_config"
        '';
      };

      programs.taskwarrior = {
        enable = true;
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

      xdg.configFile."bugwarrior/bugwarrior.toml".text = ''
        [general]
        targets = ["logseq", "github"]
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
      '';

      systemd.user = {
        services = {
          bugwarrior-pull = {
            Unit.Description = "Pull external Bugwarrior tasks into Taskwarrior";
            Service = {
              Type = "oneshot";
              ExecStart = "${bugwarriorPackage}/bin/bugwarrior pull --quiet";
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
    };
}
