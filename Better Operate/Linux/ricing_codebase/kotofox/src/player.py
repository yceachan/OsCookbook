"""Musicfox session ownership. Terminal clients only attach or detach."""
from __future__ import annotations

import os
import subprocess


class Player:
    def __init__(self, binary: str, tmux: tuple[str, ...] = ("/usr/bin/tmux",)) -> None:
        self.binary = binary
        self.tmux = tmux
        self.session = "musicfox"

    def command(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run((*self.tmux, *args), text=True, capture_output=True, timeout=5)

    def running(self) -> bool:
        result = self.command("-N", "list-sessions", "-F", "#{session_name}")
        if result.returncode:
            # tmux reports the absence of a server as exit 1.
            if "no server running" in result.stderr or "No such file or directory" in result.stderr:
                return False
            raise RuntimeError(result.stderr.strip())
        return self.session in result.stdout.splitlines()

    def start(self) -> None:
        if self.running():
            return
        # Use the normal server so ~/.tmux.conf and Ctrl+Z keep their meaning.
        proxy = os.environ.get("http_proxy") or os.environ.get("HTTP_PROXY") or "http://127.0.0.1:7897"
        https_proxy = os.environ.get("https_proxy") or os.environ.get("HTTPS_PROXY") or proxy
        result = self.command(
            "new-session", "-d", "-s", self.session,
            "-e", f"http_proxy={proxy}", "-e", f"https_proxy={https_proxy}",
            "-e", f"HTTP_PROXY={proxy}", "-e", f"HTTPS_PROXY={https_proxy}",
            self.binary,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip())

    def stop(self) -> None:
        if self.running():
            result = self.command("kill-session", "-t", f"={self.session}")
            if result.returncode:
                raise RuntimeError(result.stderr.strip())
