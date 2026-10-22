"""Copy the addon files listed in the TOC into an installable directory."""

from pathlib import Path
from shutil import copy2
import sys


ROOT = Path(__file__).resolve().parents[1]


def manifest():
    entries = [Path("Warlock_Hud.toc")]
    for line in (ROOT / "Warlock_Hud.toc").read_text(encoding="utf-8-sig").splitlines():
        name = line.strip()
        if not name or name.startswith("#"):
            continue
        path = Path(name.replace("\\", "/"))
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"Invalid TOC path: {name}")
        entries.append(path)
    entries.extend((
        Path("Textures/ThreatDot.tga"),
        Path("Textures/WelcomeBasic.tga"),
        Path("Textures/WelcomeAdvanced.tga"),
        Path("README.md"),
        Path("LICENSE"),
    ))
    return entries


def package(destination):
    for relative in manifest():
        source = ROOT / relative
        if not source.is_file():
            raise FileNotFoundError(source)
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        copy2(source, target)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python tools/package_addon.py DESTINATION")
    package(Path(sys.argv[1]))
