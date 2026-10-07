#!/usr/bin/env python3
"""Install this machine's FSearch prototype and retain its original settings."""

import configparser
import json
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parent
HOME = Path.home()
CONFIG = HOME / ".config"
DATA = HOME / ".local/share"
STATE = HOME / ".local/state/fsearch-drawer/local-prototype-v1"
RULE = "fsearch-drawer"
SCRIPT = DATA / "kwin/scripts/fsearch-drawer"
UNIT = CONFIG / "systemd/user/fsearch-drawer.service"
ENTRY = HOME / ".local/bin/fsearch-drawer"
DESKTOP = DATA / "applications/io.github.cboxdoerfer.FSearch.desktop"
PATHS = [SCRIPT, UNIT, ENTRY, DESKTOP]


def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout.strip()


def read_config(path):
    config = configparser.RawConfigParser(strict=False)
    config.optionxform = str
    config.read(path)
    return config


def write_key(file, group, key, value):
    args = ["kwriteconfig6", "--file", str(CONFIG / file), "--group", group, "--key", key]
    if value is None:
        args.append("--delete")
    else:
        args.append(str(value))
    run(*args)


def snapshot():
    if (STATE / "before.json").exists():
        return
    STATE.mkdir(parents=True, exist_ok=True)
    for index, path in enumerate(PATHS):
        if path.exists():
            if path.is_dir():
                shutil.copytree(path, STATE / str(index))
            else:
                shutil.copy2(path, STATE / str(index))
    rules = read_config(CONFIG / "kwinrulesrc")
    order = rules.get("General", "rules").split(",")
    old_rules = {name: dict(rules[name]) for name in order
                 if rules.has_section(name) and
                 rules.get(name, "wmclass", fallback="").lower() == "io.github.cboxdoerfer.fsearch"}
    keys = [
        ("kwinrc", "Plugins", "fsearch-drawerEnabled"),
        ("fsearch/fsearch.conf", "Interface", "show_menubar"),
        ("fsearch/fsearch.conf", "Interface", "exit_on_escape"),
    ]
    saved_keys = []
    for file, group, key in keys:
        config = read_config(CONFIG / file)
        saved_keys.append([file, group, key, config.get(group, key, fallback=None)])
    enabled = subprocess.run(["systemctl", "--user", "is-enabled", "fsearch-drawer.service"],
                             capture_output=True, text=True).stdout.strip() == "enabled"
    active = subprocess.run(["systemctl", "--user", "is-active", "fsearch-drawer.service"],
                            capture_output=True, text=True).returncode == 0
    (STATE / "before.json").write_text(json.dumps({
        "keys": saved_keys, "rules": old_rules, "order": order,
        "enabled": enabled, "active": active,
        "fsearch_running": "io.github.cboxdoerfer.FSearch" in
        [name.strip() for name in run("qdbus").splitlines()],
    }, indent=2) + "\n")
    shutil.copy2(CONFIG / "fsearch/fsearch.conf", STATE / "fsearch.conf")
    shutil.copy2(CONFIG / "kwinrulesrc", STATE / "kwinrulesrc")


def stop_fsearch():
    if run("systemctl", "--user", "show", "fsearch-drawer.service", "--property=LoadState", "--value") != "not-found":
        run("systemctl", "--user", "stop", "fsearch-drawer.service")
    bus_names = run("qdbus")
    if "io.github.cboxdoerfer.FSearch" in [name.strip() for name in bus_names.splitlines()]:
        run("gdbus", "call", "--session", "--dest", "io.github.cboxdoerfer.FSearch",
            "--object-path", "/io/github/cboxdoerfer/FSearch", "--method", "org.gtk.Actions.Activate",
            "quit", "[]", "{}")
        # Wait for graceful application shutdown before editing its config.
        # Polling is bounded because quit writes the application's settings.
        for _ in range(50):
            if "io.github.cboxdoerfer.FSearch" not in [name.strip() for name in run("qdbus").splitlines()]:
                break
            time.sleep(0.1)
        else:
            raise RuntimeError("FSearch did not exit; configuration was not changed")


def reload_script():
    run("qdbus", "org.kde.KWin", "/Scripting", "unloadScript", RULE)
    run("qdbus", "org.kde.KWin", "/KWin", "reconfigure")


def apply():
    if run("kreadconfig6", "--file", "krunnerrc", "--group", "General", "--key", "FreeFloating") != "true":
        raise RuntimeError("This prototype expects the current floating KRunner layout")
    snapshot()
    stop_fsearch()
    before = json.loads((STATE / "before.json").read_text())
    rules = read_config(CONFIG / "kwinrulesrc")
    order = [name for name in rules.get("General", "rules").split(",")
             if name not in before["rules"] and name != RULE]
    for name in [*before["rules"], RULE]:
        if rules.has_section(name):
            for key in rules[name]:
                write_key("kwinrulesrc", name, key, None)
    for key, value in {
        "Description": "FSearch drawer: frameless and protected from closing",
        "wmclass": "io.github.cboxdoerfer.FSearch", "wmclassmatch": "1",
        "wmclasscomplete": "false", "types": "1", "noborder": "true", "noborderrule": "2",
        "closeable": "false", "closeablerule": "2",
        "maximizehoriz": "false", "maximizehorizrule": "2",
        "maximizevert": "false", "maximizevertrule": "2",
    }.items():
        write_key("kwinrulesrc", RULE, key, value)
    order.append(RULE)
    write_key("kwinrulesrc", "General", "rules", ",".join(order))
    write_key("kwinrulesrc", "General", "count", len(order))
    write_key("fsearch/fsearch.conf", "Interface", "show_menubar", "true")
    write_key("fsearch/fsearch.conf", "Interface", "exit_on_escape", "false")
    for path in [SCRIPT.parent, UNIT.parent, ENTRY.parent, DESKTOP.parent]:
        path.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / "src/kwin/fsearch-drawer", SCRIPT, dirs_exist_ok=True)
    shutil.copy2(ROOT / "src/fsearch-drawer.service", UNIT)
    shutil.copy2(ROOT / "src/fsearch-drawer", ENTRY)
    ENTRY.chmod(0o755)
    desktop = Path("/usr/share/applications/io.github.cboxdoerfer.FSearch.desktop").read_text()
    desktop = desktop.replace("Exec=fsearch\n", f"Exec={ENTRY}\n")
    desktop = desktop.replace("TryExec=fsearch\n", f"TryExec={ENTRY}\n")
    desktop = desktop.replace("StartupNotify=true", "StartupNotify=false")
    desktop = desktop.replace("SingleMainWindow=false", "SingleMainWindow=true")
    DESKTOP.write_text(desktop)
    write_key("kwinrc", "Plugins", "fsearch-drawerEnabled", "true")
    reload_script()
    if run("qdbus", "org.kde.KWin", "/Scripting", "isScriptLoaded", RULE) != "true":
        script_id = run("qdbus", "org.kde.KWin", "/Scripting", "loadScript",
                        str(SCRIPT / "contents/code/main.js"), RULE)
        run("qdbus", "org.kde.KWin", f"/Scripting/Script{script_id}", "run")
    run("systemctl", "--user", "daemon-reload")
    run("systemctl", "--user", "enable", "--now", "fsearch-drawer.service")
    run("kbuildsycoca6", "--noincremental")
    print(f"Installed local prototype. Original settings: {STATE}")


def rollback():
    before = json.loads((STATE / "before.json").read_text())
    stop_fsearch()
    run("systemctl", "--user", "disable", "fsearch-drawer.service")
    run("qdbus", "org.kde.KWin", "/Scripting", "unloadScript", RULE)
    for action in ["Toggle FSearch Drawer", "Show FSearch Drawer"]:
        run("qdbus", "org.kde.kglobalaccel", "/kglobalaccel", "unregister", "kwin", action)
    rules = read_config(CONFIG / "kwinrulesrc")
    if rules.has_section(RULE):
        for key in rules[RULE]:
            write_key("kwinrulesrc", RULE, key, None)
    order = [name for name in rules.get("General", "rules").split(",") if name != RULE]
    for name, values in before["rules"].items():
        for key, value in values.items():
            write_key("kwinrulesrc", name, key, value)
        if name not in order:
            index = before["order"].index(name)
            order.insert(min(index, len(order)), name)
    write_key("kwinrulesrc", "General", "rules", ",".join(order))
    write_key("kwinrulesrc", "General", "count", len(order))
    for file, group, key, value in before["keys"]:
        write_key(file, group, key, value)
    for index, path in enumerate(PATHS):
        if path.is_dir():
            shutil.rmtree(path)
        elif path.exists():
            path.unlink()
        backup = STATE / str(index)
        if backup.is_dir():
            shutil.copytree(backup, path)
        elif backup.exists():
            shutil.copy2(backup, path)
    run("systemctl", "--user", "daemon-reload")
    if before["enabled"]:
        run("systemctl", "--user", "enable", "fsearch-drawer.service")
    if before["active"]:
        run("systemctl", "--user", "start", "fsearch-drawer.service")
    run("qdbus", "org.kde.KWin", "/KWin", "reconfigure")
    run("kbuildsycoca6", "--noincremental")
    if before["fsearch_running"] and not before["active"]:
        subprocess.Popen(["/usr/bin/fsearch", "--minimized"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    history = STATE.with_name("restored-" + str(int(time.time())))
    STATE.rename(history)
    print(f"Restored original settings. Snapshot: {history}")


if __name__ == "__main__":
    operation = sys.argv[1] if len(sys.argv) > 1 else "apply"
    if operation == "apply":
        apply()
    elif operation == "rollback":
        rollback()
    elif operation == "status":
        print(run("systemctl", "--user", "show", "fsearch-drawer.service",
                  "--property=ActiveState,UnitFileState,MainPID"))
        print("KWin loaded:", run("qdbus", "org.kde.KWin", "/Scripting", "isScriptLoaded", RULE))
    else:
        raise SystemExit("Usage: try-local.py [apply|status|rollback]")
