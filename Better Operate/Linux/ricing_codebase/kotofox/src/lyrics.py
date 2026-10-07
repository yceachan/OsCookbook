"""A pinned Kotonoha composition, with Kotofox owning its tray and restart."""
from __future__ import annotations

from pathlib import Path
from collections.abc import Callable, Sequence

from kotonoha.app import composition
from kotonoha.async_worker import BlockingCallRunner
from kotonoha.config import Config, ConfigStore
from kotonoha.providers.mpris_session import MprisSession
from kotonoha.state import TrackOffsetStore
from kotonoha.tray import KotonohaTray

MUSICFOX_PREFIX = "org.mpris.MediaPlayer2.musicfox"


def is_musicfox(name: str) -> bool:
    return name == MUSICFOX_PREFIX or name.startswith(MUSICFOX_PREFIX + ".")


class MusicfoxSession(MprisSession):
    async def player_names(self) -> list[str]:
        return [name for name in await super().player_names() if is_musicfox(name)]


class EmbeddedTray(KotonohaTray):
    def show(self) -> None:
        # Retain the settings/configuration port; never register a second tray.
        pass


class RestartLauncher:
    def __init__(self, restart: Callable[[], None]) -> None:
        self.restart = restart

    def start(self, executable: str, arguments: Sequence[str]) -> bool:
        self.restart()
        return True


async def build(app, quit_port, config_dir: Path, restart: Callable[[], None]):
    # These substitutions affect only this bundled Kotonoha module. Version 0.2.3
    # provides no tray/session injection argument on its composition root.
    composition.KotonohaTray = EmbeddedTray
    composition.MprisSession = MusicfoxSession
    config_dir.mkdir(parents=True, exist_ok=True)
    store = ConfigStore(Config, config_dir / "lyrics.json")
    config_worker = BlockingCallRunner("kotofox-config")
    offset_worker = BlockingCallRunner("kotofox-offsets")
    transferred = False
    try:
        if (config_dir / "lyrics.json").exists():
            config = await config_worker.run(store.load)
        else:
            # Seed from the user's current look, then persist in Kotofox's file.
            config = await config_worker.run(ConfigStore(Config).load)
            config.port = 28746
            config.display_sources = ["mpris"]
            config.player_lock = ""
            await config_worker.run(lambda: store.save(config))
        offset_store = TrackOffsetStore(config_dir / "track-offsets.sqlite3")
        offsets = await offset_worker.run(offset_store.load)
        graph = composition.ApplicationComposition(
            app, config, config_writer=store, config_worker=config_worker,
            track_offsets=offsets, track_offset_writer=offset_store,
            track_offset_worker=offset_worker, restart_launcher=RestartLauncher(restart),
        )
        controller = graph.build()
        transferred = True
        # Replace the injected quit port so cleanup finishes before Qt exits.
        controller._quit_port = quit_port
        return controller
    finally:
        if not transferred:
            config_worker.close()
            offset_worker.close()
