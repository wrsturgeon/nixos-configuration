{ config, ... }:

let
  inherit (config.local) username;
in
{
  config.local.home-manager.users.${username} =
    { pkgs, ... }:
    let
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
    in
    {
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
