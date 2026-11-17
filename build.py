#!/usr/bin/env python3
"""Build an unofficial local macOS app from your own Steam copy of Buckshot Roulette.

Nothing of the game is included or downloaded. The game data comes from the
Windows depot that Steam put on this Mac for your account.
"""
from __future__ import annotations

import argparse
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APP_ID = "2835570"
NAME = "Buckshot Roulette"
STEAM_ROOTS = [
    Path.home() / "Library/Application Support/Steam",
    Path.home() / "Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS",
]
GDEXTENSION = '''[configuration]
entry_symbol = "godotsteam_init"
compatibility_minimum = "4.1"

[libraries]
macos.release = "osx/libgodotsteam.macos.template_release.framework"
macos.debug = "osx/libgodotsteam.macos.template_release.framework"
'''
FRAMEWORK = "libgodotsteam.macos.template_release.framework"


def find_depot_exe() -> Path | None:
    for root in STEAM_ROOTS:
        hits = sorted((root / "steamapps/content" / f"app_{APP_ID}").glob(f"depot_*/*/{NAME}.exe"))
        if hits:
            return hits[0]
    return None


def check_exe(path: Path) -> None:
    if not path.is_file():
        raise ValueError(f"Game exe not found: {path}")
    with path.open("rb") as stream:
        if stream.read(2) != b"MZ":
            raise ValueError("That is not the Windows game exe")


def app_metadata() -> dict:
    # Built from scratch: the template's Info.plist holds unfilled $placeholders.
    return {
        "CFBundleDevelopmentRegion": "English",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundlePackageType": "APPL",
        "CFBundleIdentifier": "local.buckshotroulette.steam",
        "CFBundleName": NAME,
        "CFBundleDisplayName": NAME,
        "CFBundleExecutable": NAME,
        "CFBundleIconFile": "icon.icns",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1.0",
        "LSApplicationCategoryType": "public.app-category.games",
        "LSMinimumSystemVersion": "10.12",
        "NSPrincipalClass": "NSApplication",
        "NSHighResolutionCapable": True,
        # App Nap throttles a background game, which stalls Steam lobbies.
        "NSAppSleepDisabled": True,
    }


def tool(value: Path, name: str) -> Path:
    path = value.expanduser().resolve()
    if path.suffix == ".app":
        path = path / "Contents/MacOS" / name
    if not (path.is_file() and os.access(path, os.X_OK)):
        raise ValueError(f"Executable not found: {path}")
    return path


def template_app(archive: Path, work: Path) -> Path:
    """Accept the official templates .tpz or its macos.zip; return the unpacked template app."""
    archive = archive.expanduser().resolve()
    with zipfile.ZipFile(archive) as z:
        if "templates/macos.zip" in z.namelist():
            inner = work / "macos.zip"
            with z.open("templates/macos.zip") as s, inner.open("wb") as o:
                shutil.copyfileobj(s, o)
            archive = inner
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        if "macos_template.app/Contents/MacOS/godot_macos_release.universal" not in names:
            raise ValueError("Templates must be the official Godot 4.1.x export templates (macos.zip)")
        # fixed names only; never extract arbitrary paths
        for n in ("MacOS/godot_macos_release.universal", "Resources/icon.icns"):
            z.extract(f"macos_template.app/Contents/{n}", work)
    return work / "macos_template.app"


def godotsteam_framework(source: Path, work: Path) -> Path:
    source = source.expanduser().resolve()
    if source.suffix == ".zip":
        with zipfile.ZipFile(source) as z:
            members = [n for n in z.namelist() if f"{FRAMEWORK}/" in n]
            if not members:
                raise ValueError(f"{FRAMEWORK} not found in the GodotSteam zip")
            if any(Path(n).is_absolute() or ".." in Path(n).parts for n in members):
                raise ValueError("Unsafe path in zip")
            z.extractall(work / "gs", members)
        source = next((work / "gs").rglob(FRAMEWORK))
    elif source.name != FRAMEWORK:
        source = source / "osx" / FRAMEWORK if (source / "osx").exists() else source / FRAMEWORK
    if not (source / "libgodotsteam.macos.template_release").is_file():
        raise ValueError(f"Not a GodotSteam macOS release framework: {source}")
    return source


def run(args: list[str], log: Path, cwd: Path | None = None) -> None:
    with log.open("ab") as stream:
        stream.write(("\n$ " + " ".join(args) + "\n").encode())
        code = subprocess.run(args, stdout=stream, stderr=subprocess.STDOUT, cwd=cwd).returncode
    if code:
        raise RuntimeError(f"Step failed ({code}); see {log}")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game", type=Path, help=f"{NAME}.exe from your Steam depot (found automatically if omitted)")
    p.add_argument("--godot", required=True, type=Path, help="Official Godot 4.1.x .app or executable")
    p.add_argument("--templates", required=True, type=Path, help="Godot 4.1.x export templates .tpz or macos.zip")
    p.add_argument("--godotsteam", required=True, type=Path,
                   help="GodotSteam GDExtension for Godot 4.1 (folder with osx/, the .framework, or the release zip)")
    p.add_argument("--icon", type=Path, help="optional local .icns; none is included in this repository")
    p.add_argument("--output", type=Path, default=ROOT / "build" / f"{NAME}.app")
    p.add_argument("--i-own-the-game", action="store_true", help="confirm you own the game on Steam (asked otherwise)")
    a = p.parse_args(argv)
    if sys.platform != "darwin":
        raise ValueError("This builder runs on macOS")
    print(f"This builds a Mac app from your own Steam copy of {NAME}. It includes and downloads none of the game.")
    print(f"Buy it at https://store.steampowered.com/app/{APP_ID}/")
    if not a.i_own_the_game:
        if not sys.stdin.isatty():
            raise ValueError("Confirm that you own the game: add --i-own-the-game")
        if input(f"Do you own {NAME} on Steam? [y/N] ").strip().lower() not in ("y", "yes"):
            raise ValueError("This builder is only for people who own the game")
    game = a.game or find_depot_exe()
    if not game:
        raise ValueError(f"Could not find the depot. In Steam, download the Windows depot for app {APP_ID} and pass --game")
    game = game.expanduser().resolve()
    check_exe(game)
    out = a.output.expanduser().resolve()
    if out.exists() or out.suffix != ".app":
        raise ValueError("Choose a new .app output path; existing files are never overwritten")
    godot = tool(a.godot, "Godot")
    version = subprocess.check_output([str(godot), "--version"], text=True).strip()
    if not version.startswith("4.1."):
        raise ValueError(f"Use Godot 4.1.x for this game, received {version}")
    if a.icon and (not a.icon.is_file() or a.icon.suffix.lower() != ".icns"):
        raise ValueError("--icon must be an existing local .icns file")
    out.parent.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(out.parent).free < 3_000_000_000:
        raise ValueError("Not enough free disk space: the build needs about 3 GB")
    log = out.parent / f"{out.stem} - build.log"
    with tempfile.TemporaryDirectory(prefix="br-local-", dir=out.parent) as scratch:
        work = Path(scratch)
        template = template_app(a.templates, work)
        framework = godotsteam_framework(a.godotsteam, work)
        extras = work / "extras"
        (extras / ".godot").mkdir(parents=True)
        (extras / "addons/godotsteam").mkdir(parents=True)
        (extras / ".godot/extension_list.cfg").write_text("res://addons/godotsteam/godotsteam.gdextension\n")
        (extras / "addons/godotsteam/godotsteam.gdextension").write_text(GDEXTENSION)
        app = work / f"{NAME}.app"
        for sub in ("MacOS", "Resources", "Frameworks"):
            (app / "Contents" / sub).mkdir(parents=True)
        print("1/3 Repacking your game data with the Steam extension and ownership check", flush=True)
        empty = work / "cwd"
        empty.mkdir()
        run([str(godot), "--headless", "--script", str(ROOT / "tools/repack.gd"), "--",
             str(app / f"Contents/Resources/{NAME}.pck"), str(game), str(extras)], log, cwd=empty)
        if not (app / f"Contents/Resources/{NAME}.pck").is_file():
            raise RuntimeError(f"Repacking failed; see {log}")
        print("2/3 Assembling the app", flush=True)
        shutil.copy2(template / "Contents/MacOS/godot_macos_release.universal", app / f"Contents/MacOS/{NAME}")
        (app / f"Contents/MacOS/{NAME}").chmod(0o755)  # zip extraction drops the executable bit
        shutil.copytree(framework, app / "Contents/Frameworks" / FRAMEWORK, symlinks=True)
        shutil.copy2(a.icon or template / "Contents/Resources/icon.icns", app / "Contents/Resources/icon.icns")
        (app / "Contents/PkgInfo").write_text("APPL????")
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(app_metadata()))
        shutil.copy2(ROOT / "NOTICE.md", app / "Contents/Resources/Local build notice.txt")
        print("3/3 Signing and verifying locally", flush=True)
        run(["codesign", "--force", "--deep", "--sign", "-", str(app)], log)
        run(["codesign", "--verify", "--deep", "--strict", str(app)], log)
        shutil.move(str(app), out)
    print(f"Built: {out}\nLog: {log}\nThis app contains the game. Do not share it.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError, OSError, zipfile.BadZipFile) as error:
        print(f"Build stopped: {error}", file=sys.stderr)
        raise SystemExit(1)
