"""Exercise real tmux sessions without touching the user's playback."""
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))
from player import Player


class PlayerLifecycle(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="kotofox-test-", dir="/tmp")
        self.tmux = ("/usr/bin/tmux", "-S", str(Path(self.temp.name) / "tmux.sock"), "-f", "/dev/null")
        self.player = Player("/usr/bin/sleep 120", self.tmux)

    def tearDown(self):
        subprocess.run((*self.tmux, "kill-server"), capture_output=True)
        self.temp.cleanup()

    def test_repeated_start_retains_pane_and_process(self):
        self.assertFalse(self.player.running())
        self.player.start()
        result = self.player.command("list-panes", "-t", "=musicfox:", "-F", "#{pane_pid}:#{pane_id}")
        self.assertEqual(result.returncode, 0, result.stderr)
        original = result.stdout
        self.assertGreater(int(original.split(":")[0]), 0)
        self.player.start()
        result = self.player.command("list-panes", "-t", "=musicfox:", "-F", "#{pane_pid}:#{pane_id}")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(original, result.stdout)
        self.player.stop()
        self.assertFalse(self.player.running())

    def test_stop_keeps_other_sessions(self):
        self.player.start()
        result = self.player.command("new-session", "-d", "-s", "other", "/usr/bin/sleep 120")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.player.stop()
        self.assertEqual("other\n", self.player.command("list-sessions", "-F", "#{session_name}").stdout)

    def test_missing_executable_reports_failure(self):
        with self.assertRaises(FileNotFoundError):
            Player("sleep", ("/not/a/tmux",)).running()


if __name__ == "__main__":
    unittest.main()
