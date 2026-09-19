#!/usr/bin/env python3

import os
import subprocess
import time

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


BUS_NAME = "com.mitchellh.ghostty.DropdownController"
OBJECT_PATH = "/com/mitchellh/ghostty/DropdownController"
INTERFACE = BUS_NAME
RULE_GROUP = "ghostty-dropdown-initial"
GHOSTTY = os.environ["GHOSTTY_PD_DRAWER_GHOSTTY"]
TMUX = os.environ["GHOSTTY_PD_DRAWER_TMUX"]
SYSTEMD_RUN = os.environ["GHOSTTY_PD_DRAWER_SYSTEMD_RUN"]
KWRITECONFIG = os.environ["GHOSTTY_PD_DRAWER_KWRITECONFIG"]
TMUX_SESSION = os.environ.get("GHOSTTY_PD_DRAWER_TMUX_SESSION", "ghostty-pd-drawer")

INTROSPECTION_XML = f"""
<node>
  <interface name="{INTERFACE}">
    <method name="Start">
      <arg type="i" name="x" direction="in"/>
      <arg type="i" name="y" direction="in"/>
      <arg type="i" name="width" direction="in"/>
      <arg type="i" name="height" direction="in"/>
    </method>
    <method name="Promote"/>
  </interface>
</node>
"""


def write_rule_value(key, value):
    subprocess.run(
        [KWRITECONFIG, "--file", "kwinrulesrc", "--group", RULE_GROUP, "--key", key, str(value)],
        check=True,
    )


def start_ghostty(connection):
    connection.call(
        "org.freedesktop.systemd1",
        "/org/freedesktop/systemd1",
        "org.freedesktop.systemd1.Manager",
        "StartUnit",
        GLib.Variant("(ss)", ("ghostty-dropdown.service", "replace")),
        GLib.VariantType("(o)"),
        Gio.DBusCallFlags.NONE,
        -1,
        None,
        None,
    )
    return GLib.SOURCE_REMOVE


def promote_tmux_session():
    unit = f"ghostty-pd-drawer-promoted-{os.getpid()}-{time.monotonic_ns()}"
    subprocess.run(
        [
            SYSTEMD_RUN,
            "--user",
            "--collect",
            f"--unit={unit}",
            "--property=Type=exec",
            "--",
            GHOSTTY,
            "--gtk-single-instance=false",
            "-e",
            TMUX,
            "new-session",
            "-A",
            "-D",
            "-s",
            TMUX_SESSION,
        ],
        check=True,
    )


def handle_method_call(connection, sender, object_path, interface, method, parameters, invocation):
    if method == "Promote":
        try:
            promote_tmux_session()
        except subprocess.CalledProcessError as error:
            invocation.return_dbus_error(BUS_NAME + ".PromoteFailed", str(error))
            return
        invocation.return_value(None)
        return

    if method != "Start":
        invocation.return_dbus_error(BUS_NAME + ".UnknownMethod", method)
        return

    x, y, width, height = parameters.unpack()
    if width < 1 or height < 1:
        invocation.return_dbus_error(BUS_NAME + ".InvalidGeometry", "Invalid window size")
        return

    try:
        write_rule_value("position", f"{x},{y}")
        write_rule_value("size", f"{width},{height}")
    except subprocess.CalledProcessError as error:
        invocation.return_dbus_error(BUS_NAME + ".RuleWriteFailed", str(error))
        return

    connection.call(
        "org.kde.KWin",
        "/KWin",
        "org.kde.KWin",
        "reconfigure",
        None,
        None,
        Gio.DBusCallFlags.NO_AUTO_START,
        -1,
        None,
        None,
    )
    GLib.timeout_add(120, start_ghostty, connection)
    invocation.return_value(None)


def main():
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION_XML)
    connection.register_object(OBJECT_PATH, node.interfaces[0], handle_method_call, None, None)
    Gio.bus_own_name_on_connection(connection, BUS_NAME, Gio.BusNameOwnerFlags.NONE, None, None)
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
