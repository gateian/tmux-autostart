#!/usr/bin/env bash
# Install the systemd user service that runs start-sessions.sh at boot.
set -eu
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

if [[ ! -f "$HERE/sessions.conf" ]]; then
  cp "$HERE/sessions.conf.example" "$HERE/sessions.conf"
  echo "Created sessions.conf from the example; edit it to list your projects"
fi

mkdir -p "$UNIT_DIR"

cat > "$UNIT_DIR/tmux-autostart.service" <<UNIT
[Unit]
Description=Start tmux sessions from $HERE/sessions.conf

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$HERE/start-sessions.sh

[Install]
WantedBy=default.target
UNIT

systemctl --user daemon-reload
systemctl --user enable tmux-autostart.service
echo "Installed and enabled tmux-autostart.service"

if [[ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != "yes" ]]; then
  echo
  echo "To have it start at boot without logging in first, run once:"
  echo "  sudo loginctl enable-linger $USER"
fi
