# tmux-autostart

Start a set of tmux sessions at boot, each running
[Claude Code](https://docs.claude.com/en/docs/claude-code) in its own project
folder. Claude continues the folder's last conversation, or starts a new one if
there isn't one. Remote Control (`/rc`) is enabled in each Claude session,
named after the tmux session, so you can drive it from
[claude.ai/code](https://claude.ai/code) or the Claude mobile app.

Runs as a systemd user service on Linux.

## Requirements

- Linux with systemd
- tmux
- Claude Code (`claude` on your `PATH` in a login shell), already signed in

## Install

```bash
git clone https://github.com/gateian/tmux-autostart.git
cd tmux-autostart
./install.sh
```

`install.sh` creates `sessions.conf` from `sessions.conf.example` if it doesn't
exist yet, and installs and enables the `tmux-autostart` systemd user service.
To have it start at boot without logging in first, run once:

```bash
sudo loginctl enable-linger $USER
```

## Configure

Edit `sessions.conf`, one session per line:

```
# <session-name>  <project-dir>  [command]
myapp      ~/projects/myapp
devserver  ~/projects/website      npm run dev
scratch    ~                       -
```

- `project-dir` may use `~` or `$HOME`.
- With no command, Claude is started with `--continue` and Remote Control.
- Any other command is typed into the session as-is; `-` gives a plain shell.

`sessions.conf` is in `.gitignore`, so your own project list stays local.

## Usage

- Start sessions now, or pick up new entries: `./start-sessions.sh`.
  Sessions that already exist are left alone.
- Attach: `tmux attach -t myapp`
- Logs: `journalctl --user -u tmux-autostart`

Re-running `./start-sessions.sh` also turns on Remote Control in Claude
sessions that are already running without it, by typing `/remote-control` into
them. Sessions where Claude has exited to the shell are left alone.

Each session starts a login shell and types the command into it, so the shell
keeps the session alive after the command exits. At boot the script waits up
to 60 seconds for the network so Claude can reach the API.

## Caveat

Don't run `systemctl --user stop/restart tmux-autostart` unless you want to
kill every session. Systemd owns the tmux server, so stopping the service
stops all of them. To pick up new entries, just run `./start-sessions.sh`.
