#!/usr/bin/env python3

import fcntl
import logging
import math
import os
import pathlib
import shutil
import struct
import subprocess
import termios
import time

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger("ghostty-pd-drawer")


BUS_NAME = "com.mitchellh.ghostty.DropdownController"
OBJECT_PATH = "/com/mitchellh/ghostty/DropdownController"
INTERFACE = BUS_NAME
GHOSTTY = os.environ["GHOSTTY_PD_DRAWER_GHOSTTY"]
RUNTIME_DIR = pathlib.Path(os.environ["GHOSTTY_PD_DRAWER_RUNTIME_DIR"])
DRAWER_CONFIG = pathlib.Path(os.environ["GHOSTTY_PD_DRAWER_CONFIG"])
DEFAULT_CONFIG = pathlib.Path(os.environ["GHOSTTY_PD_DRAWER_DEFAULT_CONFIG"])
DEFAULT_CONFIG_GHOSTTY = pathlib.Path(os.environ["GHOSTTY_PD_DRAWER_DEFAULT_CONFIG_GHOSTTY"])
CURRENT_STATE = RUNTIME_DIR / "current"
APP_ID = "com.mitchellh.ghostty.dropdown"

# Registered by the KWin script without a key. The drawer shell prompts the
# controller to hide the window through this shortcut so no window state has to
# be guessed on the shell side. Keep the name in sync with main.js.
HIDE_SHORTCUT = "Hide Ghostty Dropdown"
KGLOBALACCEL_SERVICE = "org.kde.kglobalaccel"
KGLOBALACCEL_PATH = "/component/kwin"
KGLOBALACCEL_INTERFACE = "org.kde.kglobalaccel.Component"

INTROSPECTION_XML = f"""
<node>
  <interface name="{INTERFACE}">
    <method name="Start"/>
    <method name="Promote">
      <arg type="i" name="width" direction="in"/>
      <arg type="i" name="height" direction="in"/>
      <arg type="i" name="promoted_width" direction="out"/>
      <arg type="i" name="promoted_height" direction="out"/>
    </method>
    <method name="HideInstance">
      <arg type="s" name="instance" direction="in"/>
    </method>
    <method name="Refresh"/>
    <method name="Register">
      <arg type="i" name="pid" direction="in"/>
      <arg type="b" name="current" direction="out"/>
    </method>
    <method name="IsCurrent">
      <arg type="i" name="pid" direction="in"/>
      <arg type="b" name="current" direction="out"/>
    </method>
  </interface>
</node>
"""


def read_state():
    return CURRENT_STATE.read_text().splitlines()


def config_value(config_text, key):
    prefix = f"{key} = "
    for line in config_text.splitlines():
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return None


def config_int(config_text, key):
    try:
        return int(config_value(config_text, key))
    except (TypeError, ValueError):
        return None


def config_padding(config_text, key):
    """window-padding-x and window-padding-y take one value or "first,second"."""
    value = config_value(config_text, key)
    if value is None:
        return None
    try:
        numbers = [int(part.strip()) for part in value.split(",")]
    except ValueError:
        return None
    if len(numbers) == 1:
        return numbers[0], numbers[0]
    if len(numbers) == 2:
        return numbers[0], numbers[1]
    return None


def child_pids(pid):
    children = []
    for task in pathlib.Path(f"/proc/{pid}/task").glob("*"):
        try:
            children.extend(int(value) for value in (task / "children").read_text().split())
        except (OSError, ValueError):
            continue
    return children


def terminal_grid(pid):
    """Columns, rows and grid pixel size of the terminal running under pid.

    The tty line discipline keeps those values per PTY, so any process in the
    drawer (the shell itself or whatever runs in the foreground) reports the
    same numbers.
    """
    pending = [pid]
    seen = set()
    while pending:
        current = pending.pop(0)
        if current in seen:
            continue
        seen.add(current)
        pending.extend(child_pids(current))
        try:
            device = os.readlink(f"/proc/{current}/fd/0")
        except OSError:
            continue
        if not device.startswith("/dev/pts/"):
            continue
        try:
            handle = os.open(device, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
        except OSError:
            continue
        try:
            rows, cols, xpixel, ypixel = struct.unpack(
                "HHHH", fcntl.ioctl(handle, termios.TIOCGWINSZ, b"\0" * 8)
            )
        finally:
            os.close(handle)
        if rows and cols:
            return cols, rows, xpixel, ypixel
    return None


def registered_pid():
    try:
        lines = read_state()
        return int(lines[2]) if len(lines) >= 3 else None
    except (OSError, ValueError):
        return None


def promoted_size(config_text, frame_width, frame_height):
    """Window size Ghostty itself would give to the promoted drawer.

    Ghostty sizes a window as ceil(cells * cell_pixels) + padding, and a live
    window relates its grid to its frame the same way, so the drawer window
    calibrates the cell size instead of guessing font metrics: the promoted
    window ends up with the grid requested by window-width/window-height in the
    user's configuration, at the font and display scale in use.

    The grid area is measured from the PTY (ws_xpixel/ws_ypixel), which gives
    the exact cell aspect ratio; only the cell width comes from the frame, where
    at most one unused cell can skew it. Returns None when the size cannot be
    derived, in which case the KWin script falls back to its own geometry.
    """
    if frame_width < 1 or frame_height < 1:
        return None
    pid = registered_pid()
    grid = terminal_grid(pid) if pid else None
    if grid is None:
        return None
    cols, rows, grid_width, grid_height = grid
    if not cols or not rows:
        return None

    cells_width = config_int(config_text, "window-width")
    cells_height = config_int(config_text, "window-height")
    padding_x = config_padding(config_text, "window-padding-x")
    padding_y = config_padding(config_text, "window-padding-y")
    if not cells_width or not cells_height or padding_x is None or padding_y is None:
        return None

    padding_width = padding_x[0] + padding_x[1]
    padding_height = padding_y[0] + padding_y[1]
    cell_width = (frame_width - padding_width) / cols
    if cell_width <= 0:
        return None
    cell_height = (frame_height - padding_height) / rows
    if grid_width and grid_height:
        # Uniform scaling between the buffer and the window: the PTY aspect
        # ratio is exact even though the row count hides up to one spare cell.
        cell_height = cell_width * (grid_height / rows) / (grid_width / cols)
    if cell_height <= 0:
        return None

    return (
        math.ceil(cells_width * cell_width) + padding_width,
        math.ceil(cells_height * cell_height) + padding_height,
    )


def resolve_config(sources):
    """Resolve the merged configuration of the given config files.

    Used to read values like window-width or window-padding-x back out; the
    result is never installed as an instance config because flattening loses
    keybind attributes (see write_instance_config).
    """
    staging = RUNTIME_DIR / f".resolve-{os.getpid()}-{time.monotonic_ns()}"
    ghostty_config_dir = staging / "ghostty"
    try:
        ghostty_config_dir.mkdir(mode=0o700, parents=True)
        wrapper = ghostty_config_dir / "config"
        wrapper.write_text("".join(f"config-file = {source}\n" for source in sources))
        wrapper.chmod(0o600)

        environment = os.environ.copy()
        environment["XDG_CONFIG_HOME"] = str(staging)
        rendered = subprocess.run(
            [GHOSTTY, "+show-config"],
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        return "\n".join(
            line for line in rendered.splitlines() if not line.startswith("config-file = ")
        )
    finally:
        shutil.rmtree(staging, ignore_errors=True)


def write_instance_config(path, include_drawer):
    """Write the per-instance config and return its source files.

    The instance config stays a list of `config-file` includes instead of a
    flattened dump: `ghostty +show-config` drops keybind attributes, so a
    flattened copy turns built-in bindings like the `performable:escape=
    end_search` default into plain bindings that consume Esc even when no
    search is active.
    """
    sources = [f"?{DEFAULT_CONFIG}", f"?{DEFAULT_CONFIG_GHOSTTY}"]
    if include_drawer:
        sources.append(str(DRAWER_CONFIG))

    path.write_text("".join(f"config-file = {source}\n" for source in sources))
    path.chmod(0o600)
    return sources


def current_instance(connection):
    try:
        lines = read_state()
    except FileNotFoundError:
        return None
    if len(lines) < 2:
        raise ValueError("The active drawer state is incomplete")
    unit, config_path = lines[:2]
    try:
        unit_path = connection.call_sync(
            "org.freedesktop.systemd1", "/org/freedesktop/systemd1",
            "org.freedesktop.systemd1.Manager", "GetUnit",
            GLib.Variant("(s)", (unit,)), GLib.VariantType("(o)"),
            Gio.DBusCallFlags.NONE, -1, None,
        ).unpack()[0]
    except GLib.Error as error:
        if Gio.DBusError.get_remote_error(error) == "org.freedesktop.systemd1.NoSuchUnit":
            return None
        raise
    active = connection.call_sync(
        "org.freedesktop.systemd1", unit_path,
        "org.freedesktop.DBus.Properties", "Get",
        GLib.Variant("(ss)", ("org.freedesktop.systemd1.Unit", "ActiveState")),
        GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, -1, None,
    ).unpack()[0]
    if active not in ("active", "activating", "reloading"):
        return None
    if pathlib.Path(config_path).parent != RUNTIME_DIR or not pathlib.Path(config_path).is_file():
        raise ValueError("The active drawer config is missing or outside its runtime directory")
    return unit.removeprefix("ghostty-dropdown@").removesuffix(".service")


def warm_ghostty(connection, replace_legacy=False):
    instance = current_instance(connection)
    if instance is not None and (not replace_legacy or instance.startswith("i")):
        return instance
    instance = f"i{os.getpid()}_{time.monotonic_ns()}"
    unit = f"ghostty-dropdown@{instance}.service"
    instance_config = RUNTIME_DIR / f"{instance}.ghostty"
    RUNTIME_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    write_instance_config(instance_config, include_drawer=True)
    CURRENT_STATE.write_text(f"{unit}\n{instance_config}\n")
    CURRENT_STATE.chmod(0o600)
    connection.call_sync(
        "org.freedesktop.systemd1",
        "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager",
        "StartUnit",
        GLib.Variant("(ss)", (unit, "replace")),
        GLib.VariantType("(o)"),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )
    return instance


def activate_ghostty(connection, instance, invocation):
    application = f"{APP_ID}.{instance}"
    path = "/" + application.replace(".", "/")
    pending = {"watch": None, "timeout": None}

    def cleanup():
        Gio.bus_unwatch_name(pending["watch"])
        GLib.source_remove(pending["timeout"])

    def activated(connection, result):
        try:
            connection.call_finish(result)
        except GLib.Error as error:
            invocation.return_dbus_error(BUS_NAME + ".ActivateFailed", str(error))
        else:
            invocation.return_value(None)

    def appeared(connection, name, owner):
        cleanup()
        connection.call(
            application, path, "org.freedesktop.Application", "Activate",
            GLib.Variant("(a{sv})", ({},)), None,
            Gio.DBusCallFlags.NO_AUTO_START, -1, None, activated,
        )

    def expired():
        Gio.bus_unwatch_name(pending["watch"])
        invocation.return_dbus_error(BUS_NAME + ".StartupFailed", "Ghostty did not acquire its D-Bus name within 25 seconds")
        return GLib.SOURCE_REMOVE

    pending["watch"] = Gio.bus_watch_name_on_connection(
        connection, application, Gio.BusNameWatcherFlags.NONE, appeared, None,
    )
    pending["timeout"] = GLib.timeout_add_seconds(25, expired)


def warm_next_drawer(connection):
    try:
        warm_ghostty(connection)
    except (GLib.Error, OSError, ValueError):
        log.exception("Failed to prewarm the next drawer")
    return GLib.SOURCE_REMOVE


def reload_ghostty(connection, include_drawer):
    lines = read_state()
    if len(lines) < 2:
        raise ValueError("The active drawer state is incomplete")
    unit, config_path_text = lines[:2]
    config_path = pathlib.Path(config_path_text)
    if config_path.parent != RUNTIME_DIR or not config_path.is_file():
        # The drawer was closed without resetting the runtime state; drop the
        # stale pointer so the next drawer starts from a clean state.
        CURRENT_STATE.unlink(missing_ok=True)
        raise ValueError("The active drawer config is missing or outside its runtime directory")

    temporary = config_path.with_suffix(".reloading")
    sources = write_instance_config(temporary, include_drawer=include_drawer)
    # Only promotion needs resolved values for the normal window's geometry.
    config_text = resolve_config(sources) if not include_drawer else None
    temporary.replace(config_path)
    connection.call_sync(
        "org.freedesktop.systemd1",
        "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager",
        "ReloadUnit",
        GLib.Variant("(ss)", (unit, "replace")),
        GLib.VariantType("(o)"),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
    )
    return config_text


def promote_ghostty(connection, frame_width, frame_height):
    config_text = reload_ghostty(connection, include_drawer=False)
    size = promoted_size(config_text, frame_width, frame_height)
    CURRENT_STATE.unlink()
    log.info("promoted drawer, frame %sx%s -> %s", frame_width, frame_height, size or "default geometry")
    return size


def hide_instance(connection, instance):
    lines = read_state()
    expected = f"ghostty-dropdown@{instance}.service"
    if not instance or not lines or lines[0] != expected:
        raise ValueError("This shell does not own the active drawer")
    log.info("hiding drawer instance %s", instance)
    connection.call(
        KGLOBALACCEL_SERVICE,
        KGLOBALACCEL_PATH,
        KGLOBALACCEL_INTERFACE,
        "invokeShortcut",
        GLib.Variant("(s)", (HIDE_SHORTCUT,)),
        None,
        Gio.DBusCallFlags.NO_AUTO_START,
        -1,
        None,
        None,
    )


def register_pid(connection, pid):
    lines = read_state()
    if len(lines) < 2:
        raise ValueError("The active drawer state is incomplete")
    unit_path = connection.call_sync(
        "org.freedesktop.systemd1", "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager", "GetUnit",
        GLib.Variant("(s)", (lines[0],)), GLib.VariantType("(o)"),
        Gio.DBusCallFlags.NONE, -1, None,
    ).unpack()[0]
    main_pid = connection.call_sync(
        "org.freedesktop.systemd1", unit_path,
        "org.freedesktop.DBus.Properties", "Get",
        GLib.Variant("(ss)", ("org.freedesktop.systemd1.Service", "MainPID")),
        GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, -1, None,
    ).unpack()[0]
    if pid != main_pid:
        return False
    CURRENT_STATE.write_text(f"{lines[0]}\n{lines[1]}\n{pid}\n")
    CURRENT_STATE.chmod(0o600)
    return True


def is_current_pid(pid):
    try:
        lines = read_state()
        return len(lines) >= 3 and int(lines[2]) == pid
    except (OSError, ValueError):
        return False


def handle_method_call(connection, sender, object_path, interface, method, parameters, invocation):
    try:
        dispatch_method_call(connection, method, parameters, invocation)
    except Exception as error:  # every call must get a reply
        log.exception("%s failed", method)
        invocation.return_dbus_error(BUS_NAME + ".InternalError", f"{method}: {error}")


def dispatch_method_call(connection, method, parameters, invocation):
    if method == "Register":
        try:
            current = register_pid(connection, parameters.unpack()[0])
        except (GLib.Error, OSError, ValueError) as error:
            invocation.return_dbus_error(BUS_NAME + ".RegisterFailed", str(error))
            return
        invocation.return_value(GLib.Variant("(b)", (current,)))
        return

    if method == "IsCurrent":
        current = is_current_pid(parameters.unpack()[0])
        invocation.return_value(GLib.Variant("(b)", (current,)))
        return

    if method == "HideInstance":
        try:
            hide_instance(connection, parameters.unpack()[0])
        except (GLib.Error, OSError, ValueError) as error:
            invocation.return_dbus_error(BUS_NAME + ".HideFailed", str(error))
            return
        invocation.return_value(None)
        return

    if method == "Promote":
        frame_width, frame_height = parameters.unpack()
        try:
            size = promote_ghostty(connection, frame_width, frame_height)
        except (GLib.Error, OSError, ValueError) as error:
            invocation.return_dbus_error(BUS_NAME + ".PromoteFailed", str(error))
            return
        # 0,0 tells the KWin script to keep its own default geometry.
        invocation.return_value(GLib.Variant("(ii)", size if size else (0, 0)))
        GLib.idle_add(warm_next_drawer, connection)
        return

    if method == "Refresh":
        try:
            reload_ghostty(connection, include_drawer=True)
        except (GLib.Error, OSError, ValueError) as error:
            invocation.return_dbus_error(BUS_NAME + ".RefreshFailed", str(error))
            return
        invocation.return_value(None)
        return

    if method != "Start":
        invocation.return_dbus_error(BUS_NAME + ".UnknownMethod", method)
        return

    # GTK stays resident; Activate creates only a fresh window and shell.
    # Existing pre-resident windows are preserved during apply. Once KWin
    # requests a new window, move to a resident instance even if the old
    # process is still finishing its shutdown.
    instance = warm_ghostty(connection, replace_legacy=True)
    activate_ghostty(connection, instance, invocation)


def main():
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION_XML)
    connection.register_object(OBJECT_PATH, node.interfaces[0], handle_method_call, None, None)
    Gio.bus_own_name_on_connection(connection, BUS_NAME, Gio.BusNameOwnerFlags.NONE, None, None)
    warm_ghostty(connection)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
