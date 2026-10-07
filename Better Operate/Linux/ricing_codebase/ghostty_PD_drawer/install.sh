#!/usr/bin/env bash

set -Eeuo pipefail

operation=${1:-apply}
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
runtime_dir=${XDG_RUNTIME_DIR:-"/run/user/$(id -u)"}
state_dir="$state_home/ghostty-pd-drawer"
snapshot_dir="$state_dir/pre-shell-migration-v2"

controller_path="$HOME/.local/libexec/ghostty-dropdown-controller.py"
kwin_package_dir="$data_home/kwin/scripts/ghostty-dropdown"
systemd_dir="$config_home/systemd/user"
controller_unit="$systemd_dir/ghostty-dropdown-controller.service"
dropdown_template_unit="$systemd_dir/ghostty-dropdown@.service"
dropdown_config="$config_home/ghostty/dropdown.ghostty"
dropdown_css="$config_home/ghostty/dropdown.css"
zdotdir="$data_home/ghostty-pd-drawer/zdotdir"
user_zdotdir=${ZDOTDIR:-$HOME}

# KGlobalAccel identifies the KWin script shortcuts by these action names, and
# the keys live in the KWin script itself; the installer reads them for the
# apply summary instead of keeping a second copy.
toggle_action='Toggle Ghostty Dropdown'
promote_action='Promote Ghostty Dropdown Session'
kwin_script_source="$project_dir/src/kwin/ghostty-dropdown/contents/code/main.js"

# Fixed unit from the previous tmux implementation. Apply removes it only
# after the complete pre-apply state has been captured.
legacy_dropdown_unit="$systemd_dir/ghostty-dropdown.service"

managed_paths=(
    "$controller_path"
    "$kwin_package_dir"
    "$controller_unit"
    "$dropdown_template_unit"
    "$legacy_dropdown_unit"
    "$dropdown_config"
    "$dropdown_css"
    "$zdotdir"
)

kconfig_entries=(
    'kwinrc|Plugins|ghostty-dropdownEnabled'
    'kglobalshortcutsrc|kwin|Toggle Ghostty Dropdown'
    'kglobalshortcutsrc|kwin|Promote Ghostty Dropdown Session'
    'kwinrulesrc|General|rules'
    'kwinrulesrc|General|count'
    'kwinrulesrc|ghostty-dropdown-initial|Description'
    'kwinrulesrc|ghostty-dropdown-initial|positionrule'
    'kwinrulesrc|ghostty-dropdown-initial|sizerule'
    'kwinrulesrc|ghostty-dropdown-initial|types'
    'kwinrulesrc|ghostty-dropdown-initial|wmclass'
    'kwinrulesrc|ghostty-dropdown-initial|wmclasscomplete'
    'kwinrulesrc|ghostty-dropdown-initial|wmclassmatch'
    'kwinrulesrc|ghostty-dropdown-initial|position'
    'kwinrulesrc|ghostty-dropdown-initial|size'
)

require_command() {
    local name=$1
    if ! command -v "$name" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$name" >&2
        exit 1
    fi
}

for command_name in ghostty python3 systemctl kwriteconfig6 kreadconfig6 gdbus id rm sed; do
    require_command "$command_name"
done

script_shortcut() {
    sed -n "s/^const $1 = \"\\(.*\\)\";$/\\1/p" "$kwin_script_source"
}

toggle_shortcut=$(script_shortcut toggleShortcut)
promote_shortcut=$(script_shortcut promoteShortcut)
if [[ -z $toggle_shortcut || -z $promote_shortcut ]]; then
    printf 'Cannot read the shortcut keys from %s\n' "$kwin_script_source" >&2
    exit 1
fi

if ! python3 -c 'import gi; gi.require_version("Gio", "2.0"); from gi.repository import Gio, GLib' 2>/dev/null; then
    printf 'Python 3 PyGObject with Gio 2.0 is required.\n' >&2
    exit 1
fi

ghostty_bin=$(command -v ghostty)
python_bin=$(command -v python3)
kill_bin=$(type -P kill)
rm_bin=$(command -v rm)

qdbus_command=
for candidate in qdbus6 qdbus-qt6 qdbus; do
    if command -v "$candidate" >/dev/null 2>&1; then
        qdbus_command=$(command -v "$candidate")
        break
    fi
done

render_template() {
    local source=$1
    local target=$2
    local mode=$3

    install -d -- "$(dirname -- "$target")"
PROJECT_HOME=$HOME \
CONFIG_HOME=$config_home \
RUNTIME_DIR=$runtime_dir \
USER_ZDOTDIR=$user_zdotdir \
DRAWER_ZDOTDIR=$zdotdir \
GHOSTTY_BIN=$ghostty_bin \
    PYTHON_BIN=$python_bin \
    KILL_BIN=$kill_bin \
    RM_BIN=$rm_bin \
    CONTROLLER_PATH=$controller_path \
    python3 - "$source" "$target" <<'PY'
import os
import pathlib
import sys

source = pathlib.Path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
replacements = {
    "@HOME@": os.environ["PROJECT_HOME"],
    "@CONFIG_HOME@": os.environ["CONFIG_HOME"],
    "@RUNTIME_DIR@": os.environ["RUNTIME_DIR"],
    "@GHOSTTY_BIN@": os.environ["GHOSTTY_BIN"],
    "@PYTHON_BIN@": os.environ["PYTHON_BIN"],
    "@KILL_BIN@": os.environ["KILL_BIN"],
    "@RM_BIN@": os.environ["RM_BIN"],
    "@CONTROLLER_PATH@": os.environ["CONTROLLER_PATH"],
    "@USER_ZDOTDIR@": os.environ["USER_ZDOTDIR"],
    "@DRAWER_ZDOTDIR@": os.environ["DRAWER_ZDOTDIR"],
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
    install -Dm"$mode" -- "$source" "$target"
}

remove_exact_path() {
    local target=$1
    if [[ -L $target || -f $target ]]; then
        rm -f -- "$target"
    elif [[ -d $target ]]; then
        find "$target" -depth -delete
    fi
}

snapshot_state() {
    if [[ -d $snapshot_dir ]]; then
        return
    fi

    install -d -- "$state_dir"
    local temporary
    temporary=$(mktemp -d "$state_dir/.pre-shell-migration-v2.XXXXXX")
    install -d -- "$temporary/files" "$temporary/absent" "$temporary/kconfig"

    local index target
    for index in "${!managed_paths[@]}"; do
        target=${managed_paths[$index]}
        printf '%s\n' "$target" >> "$temporary/targets"
        if [[ -e $target || -L $target ]]; then
            cp -a -- "$target" "$temporary/files/$index"
        else
            : > "$temporary/absent/$index"
        fi
    done

    local entry file group key value sentinel
    sentinel="__ghostty_pd_drawer_absent_${RANDOM}_${RANDOM}__"
    for index in "${!kconfig_entries[@]}"; do
        entry=${kconfig_entries[$index]}
        IFS='|' read -r file group key <<< "$entry"
        printf '%s\n' "$entry" > "$temporary/kconfig/$index.entry"
        value=$(kreadconfig6 --file "$file" --group "$group" --key "$key" --default "$sentinel")
        if [[ $value == "$sentinel" ]]; then
            : > "$temporary/kconfig/$index.absent"
        else
            printf '%s' "$value" > "$temporary/kconfig/$index.value"
        fi
    done

    systemctl --user is-enabled ghostty-dropdown-controller.service > "$temporary/controller-enabled" 2>/dev/null || true
    systemctl --user is-active ghostty-dropdown-controller.service > "$temporary/controller-active" 2>/dev/null || true
    if [[ -n $qdbus_command ]] && "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded ghostty-dropdown 2>/dev/null | grep -qx true; then
        printf 'yes\n' > "$temporary/script-loaded"
    else
        printf 'no\n' > "$temporary/script-loaded"
    fi

    mv -- "$temporary" "$snapshot_dir"
    printf 'Captured pre-apply state in %s\n' "$snapshot_dir"
}

configure_kwin() {
    local rules name
    local rule_names=() retained=()
    rules=$(kreadconfig6 --file kwinrulesrc --group General --key rules)
    IFS=',' read -r -a rule_names <<< "$rules"
    for name in "${rule_names[@]}"; do
        if [[ -n $name && $name != ghostty-dropdown-initial ]]; then
            retained+=("$name")
        fi
    done
    rules=$(IFS=','; printf '%s' "${retained[*]}")
    kwriteconfig6 --file kwinrulesrc --group General --key rules "$rules"
    kwriteconfig6 --file kwinrulesrc --group General --key count "${#retained[@]}"
    local entry file group key
    for entry in "${kconfig_entries[@]}"; do
        IFS='|' read -r file group key <<< "$entry"
        if [[ $group == ghostty-dropdown-initial ]]; then
            kwriteconfig6 --file "$file" --group "$group" --key "$key" --delete
        fi
    done
    kwriteconfig6 --file kwinrc --group Plugins --key ghostty-dropdownEnabled true
}

unbound_shortcuts() {
    # Print the drawer actions the running KGlobalAccel has no binding for.
    # Runtime is the authority here: a shortcut conflict clears the binding in
    # memory first and KGlobalAccel writes kglobalshortcutsrc afterwards, so a
    # file read can still show the old key.
    python3 - "$toggle_action" "$promote_action" <<'PY'
import sys

from gi.repository import Gio, GLib

try:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION)
    infos = bus.call_sync(
        "org.kde.kglobalaccel",
        "/component/kwin",
        "org.kde.kglobalaccel.Component",
        "allShortcutInfos",
        None,
        None,
        Gio.DBusCallFlags.NONE,
        5000,
        None,
    ).unpack()[0]
except GLib.Error:
    sys.exit(1)

bound = {row[0] for row in infos if row[6]}
for action in sys.argv[1:]:
    if action not in bound:
        print(action)
PY
}

release_unbound_shortcuts() {
    # A shortcut conflict in another component clears our binding and leaves it
    # empty: undoing the other side does not bring it back, and registering the
    # same action again keeps the empty binding. Dropping the action while the
    # script is unloaded lets the reload below register it again with the key
    # from the KWin script. A binding the user assigned stays untouched.
    local action
    while IFS= read -r action; do
        if [[ -z $action ]]; then
            continue
        fi
        "$qdbus_command" org.kde.kglobalaccel /kglobalaccel org.kde.KGlobalAccel.unregister kwin "$action" >/dev/null 2>&1 || true
        printf 'Rebinding %s; it had no binding\n' "$action"
    done <<<"$1"
}

reload_kwin_script() {
    if [[ -z $qdbus_command ]] || ! "$qdbus_command" org.kde.KWin /Scripting >/dev/null 2>&1; then
        printf 'KWin is not reachable; the script will load at the next Plasma login.\n'
        return
    fi

    local attempt controller_ready=false
    for attempt in {1..50}; do
        if "$qdbus_command" com.mitchellh.ghostty.DropdownController /com/mitchellh/ghostty/DropdownController >/dev/null 2>&1; then
            controller_ready=true
            break
        fi
        sleep 0.1
    done
    if [[ $controller_ready != true ]]; then
        printf 'Controller D-Bus service did not become ready.\n' >&2
        return 1
    fi

    local unbound
    unbound=$(unbound_shortcuts 2>/dev/null || true)
    "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript ghostty-dropdown >/dev/null 2>&1 || true
    release_unbound_shortcuts "$unbound"
    "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$kwin_package_dir/contents/code/main.js" ghostty-dropdown >/dev/null
    "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
    "$qdbus_command" org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
}

install_zdotdir_overlay() {
    # A drawer-only zsh startup file. The overlay only redirects ZDOTDIR, so the
    # user's own .zshenv/.zprofile/.zshrc keep running exactly as usual.
    remove_exact_path "$zdotdir"
    render_template "$project_dir/src/zsh/drawer-zshrc.in" "$zdotdir/.zshrc" 0644
    local name
    for name in zshenv zprofile zlogin; do
        ln -s -- "$user_zdotdir/.$name" "$zdotdir/.$name"
    done
}

apply_feature() {
    local validation_dir
    validation_dir=$(mktemp -d)
    render_template "$project_dir/src/ghostty/dropdown.ghostty.in" "$validation_dir/dropdown.ghostty" 0644
    ghostty +validate-config --config-file="$validation_dir/dropdown.ghostty"
    find "$validation_dir" -depth -delete
    python3 -c 'import pathlib; compile(pathlib.Path("'"$project_dir"'/src/libexec/ghostty-dropdown-controller.py").read_text(), "controller.py", "exec")'
    snapshot_state

    remove_exact_path "$kwin_package_dir"
    render_template "$project_dir/src/ghostty/dropdown.ghostty.in" "$dropdown_config" 0644
    # The drawer takes its corner radius from the GTK theme through client-side
    # decorations, so the previous explicit stylesheet is obsolete.
    remove_exact_path "$dropdown_css"
    install_source "$project_dir/src/libexec/ghostty-dropdown-controller.py" "$controller_path" 0755
    install_source "$project_dir/src/kwin/ghostty-dropdown/metadata.json" "$kwin_package_dir/metadata.json" 0644
    install_source "$kwin_script_source" "$kwin_package_dir/contents/code/main.js" 0644
    render_template "$project_dir/src/systemd/ghostty-dropdown-controller.service.in" "$controller_unit" 0644
    render_template "$project_dir/src/systemd/ghostty-dropdown@.service.in" "$dropdown_template_unit" 0644
    install_zdotdir_overlay

    remove_exact_path "$legacy_dropdown_unit"
    configure_kwin

    systemctl --user daemon-reload
    systemctl --user enable --now ghostty-dropdown-controller.service
    systemctl --user restart ghostty-dropdown-controller.service
    reload_kwin_script
    local active_unit
    if [[ -f $runtime_dir/ghostty-pd-drawer/current ]]; then
        IFS= read -r active_unit < "$runtime_dir/ghostty-pd-drawer/current"
    fi
    if [[ -n $qdbus_command && ${active_unit:-} == ghostty-dropdown@i*_*.service ]]; then
        "$qdbus_command" com.mitchellh.ghostty.DropdownController \
            /com/mitchellh/ghostty/DropdownController \
            com.mitchellh.ghostty.DropdownController.Refresh >/dev/null 2>&1 || true
    fi

    printf '\nApplied Ghostty resident drawer.\n'
    printf '  %-6s toggle the current drawer\n' "$toggle_shortcut"
    printf '  %-6s hide the drawer at the shell prompt\n' Esc
    printf '  %-6s promote the drawer to a normal Ghostty window\n' "$promote_shortcut"
    printf '  %-6s close the shell; keep GTK warm for the next drawer\n' exit
    if [[ -n ${active_unit:-} && $active_unit != ghostty-dropdown@i*_*.service ]]; then
        printf '  An existing on-demand drawer is preserved; exit it once to switch to the resident process.\n'
    fi
    if systemctl --user is-active --quiet ghostty-dropdown.service; then
        printf '  A pre-migration tmux drawer is still running; close it once before testing the new path.\n'
    fi
}

check_file() {
    local expected=$1
    local actual=$2
    local label=$3
    if [[ -f $actual ]] && cmp -s -- "$expected" "$actual"; then
        printf 'ok    %s\n' "$label"
    else
        printf 'FAIL  %s\n' "$label"
        status_failed=1
    fi
}

check_kconfig() {
    local file=$1 group=$2 key=$3 expected=$4 label=$5
    local actual
    actual=$(kreadconfig6 --file "$file" --group "$group" --key "$key" --default '__absent__')
    if [[ $actual == "$expected" ]]; then
        printf 'ok    %s\n' "$label"
    else
        printf 'FAIL  %s (got %s)\n' "$label" "$actual"
        status_failed=1
    fi
}

check_zdotdir_link() {
    local name=$1
    local actual
    actual=$(readlink -- "$zdotdir/.$name" 2>/dev/null || true)
    if [[ $actual == "$user_zdotdir/.$name" ]]; then
        printf 'ok    zsh overlay link .%s\n' "$name"
    else
        printf 'FAIL  zsh overlay link .%s (got %s)\n' "$name" "${actual:-<absent>}"
        status_failed=1
    fi
}

status_feature() {
    status_failed=0
    local temporary
    temporary=$(mktemp -d)
    render_template "$project_dir/src/ghostty/dropdown.ghostty.in" "$temporary/dropdown.ghostty" 0644
    render_template "$project_dir/src/systemd/ghostty-dropdown-controller.service.in" "$temporary/controller.service" 0644
    render_template "$project_dir/src/systemd/ghostty-dropdown@.service.in" "$temporary/dropdown@.service" 0644
    render_template "$project_dir/src/zsh/drawer-zshrc.in" "$temporary/drawer.zshrc" 0644

    check_file "$temporary/dropdown.ghostty" "$dropdown_config" 'drawer config'
    check_file "$temporary/drawer.zshrc" "$zdotdir/.zshrc" 'drawer zsh startup file'
    check_zdotdir_link zshenv
    check_zdotdir_link zprofile
    check_zdotdir_link zlogin
    check_file "$project_dir/src/libexec/ghostty-dropdown-controller.py" "$controller_path" controller
    check_file "$project_dir/src/kwin/ghostty-dropdown/metadata.json" "$kwin_package_dir/metadata.json" 'KWin metadata'
    check_file "$kwin_script_source" "$kwin_package_dir/contents/code/main.js" 'KWin script'
    check_file "$temporary/controller.service" "$controller_unit" 'controller unit'
    check_file "$temporary/dropdown@.service" "$dropdown_template_unit" 'drawer instance unit'
    find "$temporary" -depth -delete

    local obsolete
    for obsolete in "$legacy_dropdown_unit" "$dropdown_css"; do
        if [[ -e $obsolete || -L $obsolete ]]; then
            printf 'FAIL  obsolete artifact remains: %s\n' "$obsolete"
            status_failed=1
        else
            printf 'ok    obsolete artifact absent: %s\n' "$obsolete"
        fi
    done

    if systemctl --user is-enabled --quiet ghostty-dropdown-controller.service; then
        printf 'ok    controller enabled\n'
    else
        printf 'FAIL  controller not enabled\n'
        status_failed=1
    fi
    if systemctl --user is-active --quiet ghostty-dropdown-controller.service; then
        printf 'ok    controller active\n'
    else
        printf 'FAIL  controller not active\n'
        status_failed=1
    fi

    check_kconfig kwinrc Plugins ghostty-dropdownEnabled true 'KWin plugin enabled'

    local rules
    rules=$(kreadconfig6 --file kwinrulesrc --group General --key rules 2>/dev/null || true)
    if [[ ,$rules, != *,ghostty-dropdown-initial,* ]]; then
        printf 'ok    obsolete initial window rule removed\n'
    else
        printf 'FAIL  obsolete initial window rule remains\n'
        status_failed=1
    fi

    if [[ -n $qdbus_command ]] && "$qdbus_command" org.kde.KWin /Scripting >/dev/null 2>&1; then
        if "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.isScriptLoaded ghostty-dropdown 2>/dev/null | grep -qx true; then
            printf 'ok    KWin script loaded\n'
        else
            printf 'FAIL  KWin script not loaded\n'
            status_failed=1
        fi
    else
        printf 'info  KWin runtime is not reachable\n'
    fi

    if systemctl --user is-active --quiet ghostty-dropdown.service; then
        printf 'info  pre-migration tmux drawer remains active until it is closed\n'
    fi

    if unbound_actions=$(unbound_shortcuts 2>/dev/null); then
        local shortcut
        for shortcut in "$toggle_action" "$promote_action"; do
            if grep -qxF -- "$shortcut" <<<"$unbound_actions"; then
                printf 'info  shortcut %s: unbound\n' "$shortcut"
            else
                printf 'info  shortcut %s: bound\n' "$shortcut"
            fi
        done
    else
        printf 'info  shortcut bindings unknown: the KWin runtime did not answer\n'
    fi

    return "$status_failed"
}

restore_kconfig() {
    local index entry file group key value
    for index in "${!kconfig_entries[@]}"; do
        entry=$(<"$snapshot_dir/kconfig/$index.entry")
        IFS='|' read -r file group key <<< "$entry"
        if [[ -f $snapshot_dir/kconfig/$index.absent ]]; then
            kwriteconfig6 --file "$file" --group "$group" --key "$key" --delete ''
        else
            value=$(<"$snapshot_dir/kconfig/$index.value")
            kwriteconfig6 --file "$file" --group "$group" --key "$key" "$value"
        fi
    done
}

rollback_feature() {
    if [[ ! -d $snapshot_dir ]]; then
        printf 'No active pre-apply snapshot; nothing to roll back.\n'
        return
    fi

    if [[ -n $qdbus_command ]] && "$qdbus_command" org.kde.KWin /Scripting >/dev/null 2>&1; then
        "$qdbus_command" org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Promote Ghostty Dropdown Session' >/dev/null 2>&1 || true
        sleep 0.3
        "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript ghostty-dropdown >/dev/null 2>&1 || true
    fi
    systemctl --user disable --now ghostty-dropdown-controller.service >/dev/null 2>&1 || true

    # Promotion starts a fresh, windowless resident. Stop only that empty
    # process; a migrated terminal with a shell must survive rollback.
    local active_state=()
    if [[ -f $runtime_dir/ghostty-pd-drawer/current ]]; then
        mapfile -t active_state < "$runtime_dir/ghostty-pd-drawer/current"
        if [[ ${#active_state[@]} == 2 && ${active_state[0]} == ghostty-dropdown@i*_*.service ]]; then
            systemctl --user stop "${active_state[0]}"
            rm -f -- "$runtime_dir/ghostty-pd-drawer/current"
        fi
    fi

    local saved_targets=()
    mapfile -t saved_targets < "$snapshot_dir/targets"
    local index target
    for index in "${!saved_targets[@]}"; do
        target=${saved_targets[$index]}
        remove_exact_path "$target"
        if [[ -e $snapshot_dir/files/$index || -L $snapshot_dir/files/$index ]]; then
            install -d -- "$(dirname -- "$target")"
            cp -a -- "$snapshot_dir/files/$index" "$target"
        fi
    done
    restore_kconfig
    systemctl --user daemon-reload

    local enabled active
    enabled=$(<"$snapshot_dir/controller-enabled")
    active=$(<"$snapshot_dir/controller-active")
    if [[ $enabled == enabled ]]; then
        systemctl --user enable ghostty-dropdown-controller.service >/dev/null
    else
        systemctl --user disable ghostty-dropdown-controller.service >/dev/null 2>&1 || true
    fi
    if [[ $active == active ]]; then
        systemctl --user restart ghostty-dropdown-controller.service
    else
        systemctl --user stop ghostty-dropdown-controller.service >/dev/null 2>&1 || true
    fi

    if [[ -n $qdbus_command ]] && [[ $(<"$snapshot_dir/script-loaded") == yes ]]; then
        "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$kwin_package_dir/contents/code/main.js" ghostty-dropdown >/dev/null
        "$qdbus_command" org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
        "$qdbus_command" org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
    fi

    local history_dir="$state_dir/history"
    local archived="$history_dir/$(date +%Y%m%d-%H%M%S)-pre-shell-migration-v2"
    install -d -- "$history_dir"
    if [[ -e $archived ]]; then
        archived="$archived-$$"
    fi
    mv -- "$snapshot_dir" "$archived"
    printf 'Rollback complete; snapshot retained at %s\n' "$archived"
}

case "$operation" in
    apply)
        apply_feature
        status_feature
        ;;
    status)
        status_feature
        ;;
    rollback)
        rollback_feature
        ;;
    *)
        printf 'Usage: %s {apply|status|rollback}\n' "$0" >&2
        exit 2
        ;;
esac
