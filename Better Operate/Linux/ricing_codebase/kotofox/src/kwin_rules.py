#!/usr/bin/python3
"""Associate the dedicated Ghostty window with the Kotofox taskbar entry."""
import configparser
import os
from pathlib import Path


def install():
    path = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "kwinrulesrc"
    config = configparser.RawConfigParser()
    config.optionxform = str
    config.read(path)
    if not config.has_section("General"):
        config.add_section("General")
    rules = [rule for rule in config.get("General", "rules", fallback="").split(",") if rule]
    if "kotofox-player" not in rules:
        rules.append("kotofox-player")
    config.set("General", "rules", ",".join(rules))
    config.set("General", "count", str(len(rules)))
    config["kotofox-player"] = {
        "Description": "Kotofox Ghostty player window",
        "wmclass": "com.mitchellh.ghostty.kotofox",
        "wmclasscomplete": "false",
        "wmclassmatch": "1",
        "desktopfile": "kotofox",
        "desktopfilerule": "2",
    }
    with path.open("w") as stream:
        config.write(stream, space_around_delimiters=False)


if __name__ == "__main__":
    install()
