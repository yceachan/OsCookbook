#!/usr/bin/env bash

set -Eeuo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
tmux_session=${GHOSTTY_PD_DRAWER_TMUX_SESSION:-ghostty-pd-drawer}

if [[ ! $tmux_session =~ ^[A-Za-z0-9_.-]+$ ]]; then
    printf 'Invalid tmux session name: %s\n' "$tmux_session" >&2
    exit 2
fi

require_command() {
    local name=$1
    if ! command -v "$name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$name" >&2
        exit 1
    fi
}

for command_name in ghostty tmux python3 systemctl systemd-run kwriteconfig6 kreadconfig6; do
    require_command "$command_name"
done

if ! python3 -c 'import gi; gi.require_version("Gio", "2.0"); from gi.repository import Gio, GLib' 2>/dev/null; then
    printf 'Python 3 PyGObject with Gio 2.0 is required.\n' >&2
    exit 1
fi

if ! ghostty +list-actions 2>/dev/null | grep -qx toggle_maximize; then
    printf 'This Ghostty build does not provide the toggle_maximize action. Ghostty 1.3+ is recommended.\n' >&2
    exit 1
fi

ghostty_bin=$(command -v ghostty)
tmux_bin=$(command -v tmux)
python_bin=$(command -v python3)
systemd_run_bin=$(command -v systemd-run)
kwriteconfig_bin=$(command -v kwriteconfig6)

ghostty_dir="$config_home/ghostty"
controller_path="$HOME/.local/libexec/ghostty-dropdown-controller.py"
kwin_package_dir="$data_home/kwin/scripts/ghostty-dropdown"
systemd_dir="$config_home/systemd/user"
backup_dir="$state_home/ghostty-pd-drawer/backups"

backup_once() {
    local target=$1
    local relative=${target#/}
    local backup="$backup_dir/$relative"

    if [[ -e $target && ! -e $backup ]]; then
        install -d -- "$(dirname -- "$backup")"
        cp -a -- "$target" "$backup"
        printf 'Backed up %s -> %s\n' "$target" "$backup"
    fi
}

render_template() {
    local source=$1
    local target=$2
    local mode=$3

    install -d -- "$(dirname -- "$target")"
    PROJECT_HOME=$HOME \
    CONFIG_HOME=$config_home \
    GHOSTTY_BIN=$ghostty_bin \
    TMUX_BIN=$tmux_bin \
    PYTHON_BIN=$python_bin \
    SYSTEMD_RUN_BIN=$systemd_run_bin \
    KWRITECONFIG_BIN=$kwriteconfig_bin \
    CONTROLLER_PATH=$controller_path \
    TMUX_SESSION=$tmux_session \
    python3 - "$source" "$target" <<'PY'
import os
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
replacements = {
    "@HOME@": os.environ["PROJECT_HOME"],
    "@CONFIG_HOME@": os.environ["CONFIG_HOME"],
    "@GHOSTTY_BIN@": os.environ["GHOSTTY_BIN"],
    "@TMUX_BIN@": os.environ["TMUX_BIN"],
    "@PYTHON_BIN@": os.environ["PYTHON_BIN"],
    "@SYSTEMD_RUN_BIN@": os.environ["SYSTEMD_RUN_BIN"],
    "@KWRITECONFIG_BIN@": os.environ["KWRITECONFIG_BIN"],
    "@CONTROLLER_PATH@": os.environ["CONTROLLER_PATH"],
    "@TMUX_SESSION@": os.environ["TMUX_SESSION"],
}
content = source.read_text()
for marker, value in replacements.items():
    content = content.replace(marker, value)
target.write_text(content)
PY
    chmod "$mode" "$target"
}

install_source() {
    local source=$1
    local target=$2
    local mode=$3

    backup_once "$target"
    install -Dm"$mode" -- "$source" "$target"
}

dropdown_config="$ghostty_dir/dropdown.ghostty"
controller_unit="$systemd_dir/ghostty-dropdown-controller.service"
dropdown_unit="$systemd_dir/ghostty-dropdown.service"

for target in "$dropdown_config" "$controller_unit" "$dropdown_unit"; do
    backup_once "$target"
done

render_template "$project_dir/src/ghostty/dropdown.ghostty.in" "$dropdown_config" 0644
install_source "$project_dir/src/ghostty/dropdown.css" "$ghostty_dir/dropdown.css" 0644
install_source "$project_dir/src/libexec/ghostty-dropdown-controller.py" "$controller_path" 0755
install_source "$project_dir/src/kwin/ghostty-dropdown/metadata.json" "$kwin_package_dir/metadata.json" 0644
install_source "$project_dir/src/kwin/ghostty-dropdown/contents/code/main.js" "$kwin_package_dir/contents/code/main.js" 0644
render_template "$project_dir/src/systemd/ghostty-dropdown-controller.service.in" "$controller_unit" 0644
render_template "$project_dir/src/systemd/ghostty-dropdown.service.in" "$dropdown_unit" 0644

rule_group=ghostty-dropdown-initial
rules=$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)
if [[ ,$rules, != *,$rule_group,* ]]; then
    rules=${rules:+$rules,}$rule_group
fi

IFS=',' read -r -a rule_names <<< "$rules"
kwriteconfig6 --file kwinrulesrc --group General --key rules "$rules"
kwriteconfig6 --file kwinrulesrc --group General --key count "${#rule_names[@]}"
kwriteconfig6 --file kwinrulesrc --group "$rule_group" --key Description 'Ghostty drop-down initial geometry'
kwriteconfig6 --file kwinrulesrc --group "$rule_group" --key positionrule 3
kwriteconfig6 --file kwinrulesrc --group "$rule_group" --key sizerule 3
kwriteconfig6 --file kwinrulesrc --group "$rule_group" --key types 1
kwriteconfig6 --file kwinrulesrc --group "$rule_group" --key wmclass com.mitchellh.ghostty.dropdown
kwriteconfig6 --file kwinrulesrc --group "$rule_group" --key wmclasscomplete false
kwriteconfig6 --file kwinrulesrc --group "$rule_group" --key wmclassmatch 1
kwriteconfig6 --file kwinrc --group Plugins --key ghostty-dropdownEnabled true

systemctl --user daemon-reload
systemctl --user enable --now ghostty-dropdown-controller.service
systemctl --user restart ghostty-dropdown-controller.service

qdbus_command=
for candidate in qdbus6 qdbus-qt6 qdbus; do
    if command -v "$candidate" >/dev/null 2>&1; then
        qdbus_command=$(command -v "$candidate")
        break
    fi
done

if [[ -n $qdbus_command ]] && "$qdbus_command" org.kde.KWin /Scripting >/dev/null 2>&1; then
    "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript ghostty-dropdown >/dev/null 2>&1 || true
    "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$kwin_package_dir/contents/code/main.js" ghostty-dropdown >/dev/null
    "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
    "$qdbus_command" org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
else
    printf 'KWin is not reachable; the script will load at the next Plasma login.\n'
fi

ghostty +validate-config --config-file="$dropdown_config"

printf '\nInstalled ghostty_PD_drawer.\n'
printf '  Meta+`  toggle drawer\n'
printf '  Escape  hide focused drawer\n'
printf '  Meta+F  transfer tmux session to a normal Ghostty window\n'
printf '  tmux session: %s\n' "$tmux_session"
printf 'Close an already-running pre-install drawer once before testing the tmux startup.\n'
