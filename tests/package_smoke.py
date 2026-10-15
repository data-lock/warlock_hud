"""Ensure the installable package contains every TOC entry."""

from pathlib import Path
import sys
from tempfile import TemporaryDirectory


sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from package_addon import manifest, package  # noqa: E402


with TemporaryDirectory() as temporary:
    destination = Path(temporary) / "Warlock_Hud"
    package(destination)
    expected = set(manifest())
    actual = {
        file.relative_to(destination)
        for file in destination.rglob("*")
        if file.is_file()
    }
    assert actual == expected, (expected - actual, actual - expected)

print(f"Package contains all {len(expected)} manifest files")
