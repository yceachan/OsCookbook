"""The UDA C ABI is the only owner of the Kotofox tray."""
from __future__ import annotations

import ctypes as c
from pathlib import Path
from collections.abc import Callable

TextCallback = c.CFUNCTYPE(None, c.c_uint64, c.c_void_p)


class Tray:
    def __init__(self, library: Path, icon: Path, dispatch: Callable[[str], None]) -> None:
        self.lib = c.CDLL(str(library))
        self.callbacks: list[object] = []
        self.handle = c.c_uint64()
        self.menu = c.c_uint64()
        signatures = {
            "uda_last_error_message": ([], c.c_void_p),
            "uda_free_string": ([c.c_void_p], None),
            "uda_tray_create": ([c.c_char_p, c.c_char_p, c.POINTER(c.c_uint64)], c.c_int32),
            "uda_tray_set_icon_path": ([c.c_uint64, c.c_char_p], c.c_int32),
            "uda_tray_set_tooltip": ([c.c_uint64, c.c_char_p], c.c_int32),
            "uda_tray_menu_create": ([c.POINTER(c.c_uint64)], c.c_int32),
            "uda_tray_menu_add_text": ([c.c_uint64, c.c_char_p, TextCallback, c.c_void_p, c.POINTER(c.c_uint64)], c.c_int32),
            "uda_tray_menu_add_separator": ([c.c_uint64], c.c_int32),
            "uda_tray_set_menu": ([c.c_uint64, c.c_uint64], c.c_int32),
            "uda_tray_destroy": ([c.c_uint64], c.c_int32),
            "uda_tray_menu_destroy": ([c.c_uint64], c.c_int32),
        }
        for name, (args, result) in signatures.items():
            function = getattr(self.lib, name)
            function.argtypes = args
            function.restype = result
        try:
            self.call("uda_tray_create", b"Kotofox", b"Kotofox", c.byref(self.handle))
            self.call("uda_tray_set_icon_path", self.handle, str(icon).encode())
            self.call("uda_tray_menu_create", c.byref(self.menu))
            entries = (
                ("打开播放器", "open"), ("关闭播放器窗口，保留播放", "detach"),
                (None, None), ("显示桌面歌词", "lyrics-on"), ("隐藏桌面歌词", "lyrics-off"),
                ("歌词穿透：开", "passthrough-on"), ("歌词穿透：关", "passthrough-off"),
                ("歌词设置", "settings"), (None, None),
                ("Kotofox 管理", "manage"), ("播放 / 暂停", "toggle"),
                ("上一首", "previous"), ("下一首", "next"), (None, None),
                ("退出 Kotofox，保留播放", "quit"), ("退出并停止播放器", "quit-all"),
            )
            for label, action in entries:
                if label is None:
                    self.call("uda_tray_menu_add_separator", self.menu)
                    continue
                callback = TextCallback(lambda _item, _data, action=action: dispatch(action))
                self.callbacks.append(callback)
                item = c.c_uint64()
                self.call("uda_tray_menu_add_text", self.menu, label.encode(), callback, None, c.byref(item))
            self.call("uda_tray_set_menu", self.handle, self.menu)
        except BaseException:
            self.close()
            raise

    def call(self, name: str, *args: object) -> None:
        status = getattr(self.lib, name)(*args)
        if status:
            pointer = self.lib.uda_last_error_message()
            try:
                detail = c.string_at(pointer).decode() if pointer else f"UDA status {status}"
            finally:
                if pointer:
                    self.lib.uda_free_string(pointer)
            raise RuntimeError(f"{name}: {detail}")

    def tooltip(self, text: str) -> None:
        self.call("uda_tray_set_tooltip", self.handle, text.encode())

    def close(self) -> None:
        if self.handle.value:
            self.call("uda_tray_destroy", self.handle)
            self.handle.value = 0
        if self.menu.value:
            self.call("uda_tray_menu_destroy", self.menu)
            self.menu.value = 0
        # Keep C callbacks alive through the final Rust worker shutdown.
