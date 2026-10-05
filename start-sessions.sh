#!/usr/bin/env bash
# Create the tmux sessions listed in sessions.conf. Safe to re-run: existing
# sessions are left alone, except that Claude sessions which don't have
# Remote Control enabled yet get it switched on.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${1:-$HERE/sessions.conf}"

if [[ ! -f "$CONF" ]]; then
  echo "[tmux-autostart] $CONF not found; copy sessions.conf.example to sessions.conf and edit it" >&2
  exit 1
fi

# Resume the folder's last Claude conversation; if there isn't one, start fresh.
# A normal exit from the resumed session drops to the shell instead of relaunching.
# Remote Control (/rc) is enabled and named after the tmux session.
default_cmd() {
  local rc
  rc="--remote-control $(printf %q "$1")"
  echo "claude --continue $rc || claude $rc"
}

log() { echo "[tmux-autostart] $*"; }

# At boot the network may lag behind; give it up to 60s so Claude can reach the API.
for _ in $(seq 30); do
  getent hosts api.anthropic.com >/dev/null 2>&1 && break
  sleep 2
done

while read -r name dir cmd; do
  [[ -z "${name:-}" || "$name" == \#* ]] && continue
  dir="${dir/#\~/$HOME}"
  dir="${dir//\$HOME/$HOME}"
  uses_claude=0
  if [[ -z "${cmd:-}" ]]; then
    cmd="$(default_cmd "$name")"
    uses_claude=1
  fi

  if tmux has-session -t "=$name" 2>/dev/null; then
    if (( ! uses_claude )); then
      log "$name: already running, skipping"
    elif [[ "$(tmux show-options -qv -t "=$name:" @rc)" == 1 ]]; then
      log "$name: already running with remote control, skipping"
    elif [[ "$(tmux display -p -t "=$name:" '#{pane_current_command}')" == claude ]]; then
      # Claude is already up without Remote Control: turn it on in place.
      tmux send-keys -t "=$name:" "/remote-control $name" Enter
      tmux set-option -t "=$name:" @rc 1
      log "$name: already running, enabled remote control"
    else
      log "$name: already running but Claude isn't in the foreground, skipping"
    fi
    continue
  fi
  if [[ ! -d "$dir" ]]; then
    log "$name: directory $dir not found, skipping"
    continue
  fi

  # Start a login shell so PATH (~/.local/bin etc.) is set up, then type the
  # command into it. The shell keeps the session alive after the command exits.
  tmux new-session -d -s "$name" -c "$dir"
  [[ "$cmd" != "-" ]] && tmux send-keys -t "=$name:" "$cmd" Enter
  (( uses_claude )) && tmux set-option -t "=$name:" @rc 1
  log "$name: started in $dir"
done < "$CONF"
