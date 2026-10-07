#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
automation_home="$HOME/.local/share/codex-hello"

install -d -m700 "$automation_home"
if [[ ! -e "$automation_home/auth.json" ]]; then
  ln -s "$HOME/.codex/auth.json" "$automation_home/auth.json"
fi

install -Dm644 "$script_dir/codex-hello.service" "$unit_dir/codex-hello.service"
install -Dm644 "$script_dir/codex-hello.timer" "$unit_dir/codex-hello.timer"

systemctl --user daemon-reload
systemctl --user enable --now codex-hello.timer
systemctl --user list-timers codex-hello.timer
