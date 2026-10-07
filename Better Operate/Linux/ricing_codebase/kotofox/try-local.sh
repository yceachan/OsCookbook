#!/bin/bash
# Activate the Fedora KDE prototype for this user's current desktop.
set -euo pipefail
kotofox_source=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
kotofox_root="$HOME/.local/lib/kotofox"
if [[ -e "$kotofox_root" ]]; then
    printf 'Existing Kotofox installation: %s\n' "$kotofox_root" >&2
    exit 1
fi
/usr/bin/python3 -s -c 'import PyQt6, qasync, aiohttp, dbus_fast'
test -x /usr/bin/tmux
test -x /usr/bin/ghostty
mkdir -p "$HOME/.local/lib" "$HOME/.local/bin" "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/scalable/apps" "$HOME/.config/systemd/user"
cp -a "$kotofox_source" "$kotofox_root"
sed "s|@ROOT@|$kotofox_root|g" "$kotofox_root/kotofox.desktop.in" > "$HOME/.local/share/applications/kotofox.desktop"
sed "s|@ROOT@|$kotofox_root|g" "$kotofox_root/kotofox.service.in" > "$HOME/.config/systemd/user/kotofox.service"
cp "$kotofox_root/assets/kotofox.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/kotofox.svg"
ln -s "$kotofox_root/kotofox" "$HOME/.local/bin/kotofox"
desktop-file-validate "$HOME/.local/share/applications/kotofox.desktop"
/usr/bin/python3 -s "$kotofox_root/src/kwin_rules.py"
qdbus-qt6 org.kde.KWin /KWin org.kde.KWin.reconfigure
systemctl --user daemon-reload
printf 'Kotofox prototype installed. Launch: %s open\n' "$HOME/.local/bin/kotofox"
