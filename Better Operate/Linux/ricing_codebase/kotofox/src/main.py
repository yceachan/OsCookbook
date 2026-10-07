#!/usr/bin/python3
"""Local KDE prototype. The manager, terminal and music session have separate lifetimes."""
from __future__ import annotations

import argparse
import asyncio
import fcntl
import json
import logging
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "vendor"))
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "kotofox"
RUNTIME = Path(os.environ["XDG_RUNTIME_DIR"]) / "kotofox"
SOCKET = RUNTIME / "control.sock"
LOG = logging.getLogger("kotofox")
TERMINAL_APP_ID = "com.mitchellh.ghostty.kotofox"
COMMANDS = ("open", "detach", "manage", "lyrics-on", "lyrics-off", "passthrough-on", "passthrough-off", "settings", "toggle", "previous", "next", "start", "stop", "status", "quit", "quit-all")


def request(action: str) -> dict:
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(15)
        connection.connect(str(SOCKET))
        connection.sendall((json.dumps({"action": action}) + "\n").encode())
        with connection.makefile("rb") as stream:
            return json.loads(stream.readline(65536))


def client(action: str) -> int:
    try:
        if action == "status" and not SOCKET.exists():
            print(json.dumps({"ok": True, "manager_running": False}))
            return 0
        if action != "status":
            result = subprocess.run(["systemctl", "--user", "start", "kotofox.service"], capture_output=True, text=True, timeout=20)
            if result.returncode:
                raise RuntimeError(result.stderr.strip())
        # Service startup is asynchronous until the control socket is ready.
        import time
        deadline = time.monotonic() + 20
        while True:
            try:
                result = request(action)
                break
            except (FileNotFoundError, ConnectionRefusedError):
                if time.monotonic() >= deadline:
                    raise RuntimeError("Kotofox did not start. Read: journalctl --user -u kotofox.service")
                time.sleep(0.1)
        print(json.dumps(result, ensure_ascii=False))
        return 0 if result["ok"] else 1
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f"Kotofox: {error}", file=sys.stderr)
        return 1


def daemon() -> int:
    os.umask(0o077)
    os.environ.setdefault("QT_SCALE_FACTOR", "1")
    os.environ["QT_API"] = "pyqt6"
    sys.modules["PyQt5"] = None
    from PyQt6.QtWidgets import QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QCheckBox
    from PyQt6.QtGui import QIcon
    from PyQt6.QtCore import QLockFile
    import qasync
    from dbus_fast.aio import MessageBus
    from dbus_fast import Message, MessageType
    from dbus_fast.service import ServiceInterface, method
    from dbus_fast.constants import NameFlag, RequestNameReply
    from player import Player
    from lyrics import build, is_musicfox
    from tray import Tray

    RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
    lock = (RUNTIME / "manager.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise RuntimeError("Kotofox is already running")
    # Share Kotonoha's singleton lock, so a separate launch cannot add an overlay.
    lyrics_lock = QLockFile(str(Path(os.environ["XDG_RUNTIME_DIR"]) / "kotonoha.lock"))
    if not lyrics_lock.tryLock(50):
        raise RuntimeError("Kotonoha is already running. Close it before starting Kotofox.")
    app = QApplication(["kotofox"])
    app.setApplicationName("kotofox")
    app.setApplicationDisplayName("Kotofox")
    app.setDesktopFileName("kotofox")
    app.setQuitOnLastWindowClosed(False)
    app.setProperty("xdg_current_desktop", os.environ.get("XDG_CURRENT_DESKTOP", ""))
    icon = QIcon(str(ROOT / "assets" / "kotofox.svg"))
    app.setWindowIcon(icon)
    loop = qasync.QEventLoop(app)
    asyncio.set_event_loop(loop)

    class Manager:
        def __init__(self):
            self.done = asyncio.Event()
            self.command_lock = asyncio.Lock()
            self.restart_requested = False
            self.player = Player(str(ROOT / "bin" / "musicfox"))
            self.terminal = None
            self.terminal_focused = asyncio.Event()
            self.controller = None
            self.tray = None
            self.bus = None
            self.layer_active = False
            self.lyrics_visible = True
            self.tasks: set[asyncio.Task] = set()
            self.window = QWidget()
            self.window.setWindowTitle("Kotofox")
            self.window.resize(470, 340)
            self.window.setStyleSheet("QWidget { background: #181d2c; color: #edf0f7; font-size: 14px; } QPushButton { background: #30394c; border: 0; border-radius: 8px; padding: 10px 16px; } QPushButton:hover { background: #44516b; } QLabel { padding: 4px; } QCheckBox { padding: 8px 4px; }")
            layout = QVBoxLayout(self.window)
            title = QLabel("Kotofox")
            title.setStyleSheet("font-size: 28px; color: #ffad70; font-weight: 600;")
            layout.addWidget(title)
            self.track = QLabel("读取 Musicfox…")
            self.track.setWordWrap(True)
            layout.addWidget(self.track)
            self.state = QLabel("窗口关闭后，tmux 中的播放器继续运行。")
            self.state.setWordWrap(True)
            layout.addWidget(self.state)
            for entries in ((("打开播放器", "open"), ("关闭播放器窗口", "detach")), (("上一首", "previous"), ("播放 / 暂停", "toggle"), ("下一首", "next"))):
                row = QHBoxLayout()
                for label, command in entries:
                    button = QPushButton(label)
                    button.clicked.connect(lambda checked=False, command=command: self.enqueue(command))
                    row.addWidget(button)
                layout.addLayout(row)
            self.lyrics_toggle = QCheckBox("显示桌面歌词")
            self.lyrics_toggle.setChecked(True)
            self.lyrics_toggle.toggled.connect(lambda enabled: self.enqueue("lyrics-on" if enabled else "lyrics-off"))
            layout.addWidget(self.lyrics_toggle)
            button = QPushButton("歌词设置")
            button.clicked.connect(lambda: self.enqueue("settings"))
            layout.addWidget(button)
            self.error = QLabel("")
            self.error.setWordWrap(True)
            self.error.setStyleSheet("color: #ff927d;")
            layout.addWidget(self.error)

        def quit(self):
            self.done.set()

        def restart(self):
            self.restart_requested = True
            self.quit()

        def enqueue(self, command):
            # UDA invokes callbacks on its Rust worker. Only schedule here.
            loop.call_soon_threadsafe(self.spawn, self.reported(command))

        def spawn(self, coroutine):
            task = loop.create_task(coroutine)
            self.tasks.add(task)
            task.add_done_callback(self.task_finished)

        def task_finished(self, task):
            self.tasks.discard(task)
            if not task.cancelled() and task.exception() is not None:
                LOG.error("Background operation failed", exc_info=task.exception())
                self.error.setText(str(task.exception()))

        async def reported(self, action):
            try:
                async with self.command_lock:
                    result = await self.command(action)
                self.error.setText("")
                return {"ok": True, **result}
            except (OSError, RuntimeError, subprocess.SubprocessError) as error:
                LOG.exception("Command %s failed", action)
                self.error.setText(str(error))
                return {"ok": False, "error": str(error)}

        async def close_terminal(self):
            if self.terminal is not None and self.terminal.returncode is None:
                try:
                    self.terminal.terminate()
                except ProcessLookupError:
                    # A user can close Ghostty between the check and the signal.
                    pass
                await asyncio.wait_for(self.terminal.wait(), 5)

        async def command(self, action):
            if action == "open":
                self.player.start()
                if self.terminal is None or self.terminal.returncode is not None:
                    self.terminal = await asyncio.create_subprocess_exec(
                        "/usr/bin/ghostty", f"--class={TERMINAL_APP_ID}",
                        "--gtk-single-instance=false", "--title=Kotofox", "--window-show-tab-bar=never",
                        "-e", "/usr/bin/tmux", "attach-session", "-t", "=musicfox",
                    )
                    self.spawn(self.terminal.wait())
                await self.focus_terminal()
            elif action == "detach":
                await self.close_terminal()
            elif action == "manage":
                self.window.show()
                self.window.raise_()
                self.window.activateWindow()
            elif action in ("lyrics-on", "lyrics-off"):
                self.lyrics_visible = action == "lyrics-on"
                self.controller.overlay.setVisible(self.lyrics_visible)
                self.lyrics_toggle.blockSignals(True)
                self.lyrics_toggle.setChecked(self.lyrics_visible)
                self.lyrics_toggle.blockSignals(False)
            elif action in ("passthrough-on", "passthrough-off"):
                self.controller.on_toggle_passthrough(action == "passthrough-on")
            elif action == "settings":
                self.controller.open_settings()
            elif action in ("toggle", "previous", "next"):
                names = await self.names()
                if not names:
                    raise RuntimeError("Musicfox is not running")
                await self.call(Message(destination=names[0], path="/org/mpris/MediaPlayer2", interface="org.mpris.MediaPlayer2.Player", member={"toggle": "PlayPause", "previous": "Previous", "next": "Next"}[action]))
            elif action == "start":
                self.player.start()
            elif action == "stop":
                await self.close_terminal()
                self.player.stop()
            elif action in ("quit", "quit-all"):
                if action == "quit-all":
                    self.player.stop()
                self.quit()
            elif action != "status":
                raise RuntimeError(f"Unknown command: {action}")
            return self.status()

        async def focus_terminal(self):
            self.terminal_focused.clear()
            script = RUNTIME / "focus-player.js"
            script.write_text(
                f"const terminalPid = {self.terminal.pid};\n"
                f"const terminalAppId = {json.dumps(TERMINAL_APP_ID)};\n"
                + (ROOT / "src" / "focus-player.js").read_text()
            )
            scripting = dict(destination="org.kde.KWin", path="/Scripting", interface="org.kde.kwin.Scripting")
            loaded = await self.call(Message(**scripting, member="loadScript", signature="ss", body=[str(script), "kotofox-focus-player"]))
            if loaded[0] < 0:
                raise RuntimeError("KWin could not load the Kotofox window script")
            try:
                await self.call(Message(destination="org.kde.KWin", path=f"/Scripting/Script{loaded[0]}", interface="org.kde.kwin.Script", member="run"))
                try:
                    await asyncio.wait_for(self.terminal_focused.wait(), 5)
                except TimeoutError:
                    raise RuntimeError(f"KWin did not find the Ghostty window for PID {self.terminal.pid} (exit status: {self.terminal.returncode})") from None
            finally:
                await self.call(Message(**scripting, member="unloadScript", signature="s", body=["kotofox-focus-player"]))

        def status(self):
            return {"manager_running": True, "session": "musicfox", "player_running": self.player.running(), "terminal_pid": self.terminal.pid if self.terminal is not None and self.terminal.returncode is None else None, "lyrics_visible": self.lyrics_visible, "layer_shell_active": self.layer_active, "qt_platform": app.platformName(), "tray_backend": "UniDesktop StatusNotifierItem", "config": str(CONFIG_DIR / "lyrics.json")}

        async def call(self, message):
            response = await asyncio.wait_for(self.bus.call(message), 3)
            if response.message_type == MessageType.ERROR:
                raise RuntimeError(f"{response.error_name}: {response.body}")
            return response.body

        async def names(self):
            result = await self.call(Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus", interface="org.freedesktop.DBus", member="ListNames"))
            return sorted(name for name in result[0] if is_musicfox(name))

        async def update(self):
            names = await self.names()
            if not names:
                self.track.setText("Musicfox 已停止")
                self.tray.tooltip("Kotofox · Musicfox 已停止")
                return
            result = await self.call(Message(destination=names[0], path="/org/mpris/MediaPlayer2", interface="org.freedesktop.DBus.Properties", member="GetAll", signature="s", body=["org.mpris.MediaPlayer2.Player"]))
            metadata = result[0]["Metadata"].value
            title = metadata.get("xesam:title")
            artist = metadata.get("xesam:artist")
            title = title.value if title is not None else "Musicfox"
            artist = " / ".join(artist.value) if artist is not None else ""
            state = result[0]["PlaybackStatus"].value
            self.track.setText(f"{title}\n{artist}")
            self.state.setText(f"{'正在播放' if state == 'Playing' else '已暂停' if state == 'Paused' else '已停止'} · 关闭终端后，tmux 会话继续运行。")
            self.tray.tooltip(f"Kotofox · {title}\n{artist} · {state}")

        async def polling(self):
            while not self.done.is_set():
                try:
                    await self.update()
                except (OSError, RuntimeError, TimeoutError) as error:
                    LOG.warning("Media read failed: %s", error)
                    self.error.setText(str(error))
                await asyncio.sleep(1)

        async def connection(self, reader, writer):
            try:
                message = json.loads(await asyncio.wait_for(reader.readline(), 5))
                action = message["action"]
                if action not in COMMANDS:
                    raise ValueError("Unknown command")
                result = await self.reported(action)
            except (ValueError, KeyError, TypeError, TimeoutError) as error:
                result = {"ok": False, "error": str(error)}
            try:
                writer.write((json.dumps(result, ensure_ascii=False) + "\n").encode())
                await writer.drain()
            finally:
                writer.close()
                await writer.wait_closed()

        async def run(self):
            poll_task = None
            try:
                self.bus = await MessageBus().connect()
                if await self.bus.request_name("org.kotofox.Terminal", NameFlag.DO_NOT_QUEUE) != RequestNameReply.PRIMARY_OWNER:
                    raise RuntimeError("The Kotofox terminal interface is already in use")
                self.bus.export("/Terminal", TerminalInterface(self))
                self.controller = await build(app, self, CONFIG_DIR, self.restart)
                app.setWindowIcon(icon)
                await self.controller.start()
                self.layer_active = self.controller.overlay.activate_layer_shell()
                if not self.layer_active:
                    raise RuntimeError("KDE Wayland lyric layer could not be activated")
                self.tray = Tray(ROOT / "lib" / "libuda_ffi.so", ROOT / "assets" / "kotofox.svg", self.enqueue)
                SOCKET.unlink(missing_ok=True)
                async with await asyncio.start_unix_server(self.connection, path=str(SOCKET), limit=8192):
                    poll_task = asyncio.create_task(self.polling())
                    await self.done.wait()
            finally:
                SOCKET.unlink(missing_ok=True)
                if poll_task is not None:
                    poll_task.cancel()
                    await asyncio.gather(poll_task, return_exceptions=True)
                await self.close_terminal()
                if self.controller is not None:
                    await self.controller.stop()
                if self.tray is not None:
                    self.tray.close()
                if self.bus is not None:
                    self.bus.disconnect()
                for task in tuple(self.tasks):
                    task.cancel()
                await asyncio.gather(*self.tasks, return_exceptions=True)
                self.window.close()

    class TerminalInterface(ServiceInterface):
        def __init__(self, manager):
            super().__init__("org.kotofox.Terminal")
            self.manager = manager

        @method()
        def Focused(self, pid: "s"):
            if self.manager.terminal is not None and pid == str(self.manager.terminal.pid):
                self.manager.terminal_focused.set()

    manager = Manager()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda _sig, _frame: loop.call_soon_threadsafe(manager.quit))
    with loop:
        loop.run_until_complete(manager.run())
    return 75 if manager.restart_requested else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Kotofox KDE local prototype")
    parser.add_argument("action", nargs="?", default="open", choices=COMMANDS)
    parser.add_argument("--daemon", action="store_true")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    raise SystemExit(daemon() if args.daemon else client(args.action))
