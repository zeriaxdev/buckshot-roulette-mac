#!/usr/bin/env python3
"""Build an unofficial native macOS app from your own Steam copy of Buckshot Roulette.

No part of the game is included or downloaded by this tool. The game data comes
from the Windows depot that Steam downloads for your account. The open-source
tools it needs (Godot 4.4.1, GodotSteam 4.10) are downloaded from their official
releases and checked against pinned SHA-256 hashes.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

VERSION = "1.0.0"
ROOT = Path(__file__).resolve().parent
CACHE = Path.home() / "Library/Caches/buckshot-roulette-mac"
APP_ID, DEPOT_ID = "2835570", "2835572"
NAME = "Buckshot Roulette"
STEAM_ROOTS = [
    Path.home() / "Library/Application Support/Steam",
    Path.home() / "Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS",
]
GODOT_URL = "https://github.com/godotengine/godot-builds/releases/download/4.4.1-stable/"
GODOT = (GODOT_URL + "Godot_v4.4.1-stable_macos.universal.zip",
         "6c670596d21afb7917c739d0b85b10b4ac6a44051ffa2a672f90bc7da5062864")
TEMPLATES = GODOT_URL + "Godot_v4.4.1-stable_export_templates.tpz"
RUNTIME_MEMBER = "macos_template.app/Contents/MacOS/godot_macos_release.universal"
RUNTIME_SHA = "9e680c349ea22d52fa2a84666b1fb2de15e9b59cf5f295a91da78fe09654f8b2"
GODOTSTEAM = ("https://codeberg.org/godotsteam/godotsteam/releases/download/v4.10-gde/godotsteam_gdextension_plugin41-43.zip",
              "c36ca3ece7b907658f36f90308c604eb4baf523bcffc336d764f68e5e27fddfa")
FRAMEWORK = "libgodotsteam.macos.template_release.framework"
GDEXTENSION = '''[configuration]
entry_symbol = "godotsteam_init"
compatibility_minimum = "4.1"

[libraries]
macos.release = "osx/libgodotsteam.macos.template_release.framework"
macos.debug = "osx/libgodotsteam.macos.template_release.framework"
'''
LAUNCHER = '''#!/bin/sh
# Start the game the way Steam starts its own games, so the in-game overlay (Shift+Tab,
# Invite Friends) works: same environment, Metal hook on, overlay library loaded.
export SteamAppId=2835570 SteamGameId=2835570 SteamOverlayGameId=2835570 SteamMetalHook=1
overlay="$HOME/Library/Application Support/Steam/Steam.AppBundle/Steam/Contents/MacOS/gameoverlayrenderer.dylib"
[ -f "$overlay" ] && export DYLD_INSERT_LIBRARIES="$overlay"
exec "$(dirname "$0")/Buckshot Roulette" "$@"
'''


class HttpFile(io.RawIOBase):
    """Seekable read-only view of a URL using Range requests, so zipfile can
    pull one member out of the 820 MB templates archive without downloading it all."""

    def __init__(self, url: str):
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD")) as r:
            self.url, self.size = r.url, int(r.headers["Content-Length"])
        self.pos = 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos

    def seek(self, offset, whence=0):
        self.pos = {0: offset, 1: self.pos + offset, 2: self.size + offset}[whence]
        return self.pos

    def readinto(self, buffer):
        if self.pos >= self.size or not len(buffer):
            return 0
        end = min(self.pos + len(buffer), self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req) as r:
            data = r.read()
        buffer[:len(data)] = data
        self.pos += len(data)
        return len(data)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def fetch(url: str, digest: str, target: Path) -> Path:
    if not (target.exists() and sha256(target) == digest):
        print(f"  downloading {url.rsplit('/', 1)[-1]}", flush=True)
        part = target.with_suffix(".part")
        with urllib.request.urlopen(url) as r, part.open("wb") as out:
            shutil.copyfileobj(r, out, 1 << 20)
        if sha256(part) != digest:
            part.unlink()
            raise RuntimeError(f"Checksum mismatch for {url}; nothing was used")
        part.replace(target)
    return target


def fetch_runtime(target: Path) -> Path:
    if not (target.exists() and sha256(target) == RUNTIME_SHA):
        print("  downloading the Godot 4.4.1 macOS runtime (about 115 MB, not the whole templates archive)", flush=True)
        part = target.with_suffix(".part")
        with zipfile.ZipFile(io.BufferedReader(HttpFile(TEMPLATES), 1 << 22)) as tpz:
            with zipfile.ZipFile(io.BytesIO(tpz.read("templates/macos.zip"))) as macos, part.open("wb") as out:
                out.write(macos.read(RUNTIME_MEMBER))
        if sha256(part) != RUNTIME_SHA:
            raise RuntimeError(f"Checksum mismatch for the Godot runtime ({sha256(part)}); nothing was used")
        part.replace(target)
    target.chmod(0o755)
    return target


def unpack(archive: Path, target: Path) -> Path:
    if not target.exists():
        tmp = target.with_name(target.name + ".tmp")
        shutil.rmtree(tmp, ignore_errors=True)
        subprocess.run(["ditto", "-x", "-k", str(archive), str(tmp)], check=True)  # keeps symlinks and permissions
        tmp.replace(target)
    return target


def find_depot_exe() -> Path | None:
    for root in STEAM_ROOTS:
        hits = sorted((root / "steamapps/content" / f"app_{APP_ID}").glob(f"depot_{DEPOT_ID}/*/{NAME}.exe"))
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
    return {
        "CFBundleDevelopmentRegion": "English",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundlePackageType": "APPL",
        "CFBundleIdentifier": "local.buckshotroulette.steam",
        "CFBundleName": NAME,
        "CFBundleDisplayName": NAME,
        "CFBundleExecutable": "launch",
        "CFBundleIconFile": "icon.icns",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1.0",
        "LSApplicationCategoryType": "public.app-category.games",
        "LSMinimumSystemVersion": "10.12",
        "NSPrincipalClass": "NSApplication",
        "NSHighResolutionCapable": True,
        "NSAppSleepDisabled": True,  # App Nap throttles a background game and stalls Steam lobbies
    }


def run(args: list[str], log: Path, cwd: Path | None = None) -> None:
    with log.open("ab") as stream:
        stream.write(("\n$ " + " ".join(args) + "\n").encode())
        code = subprocess.run(args, stdout=stream, stderr=subprocess.STDOUT, cwd=cwd).returncode
    if code:
        raise RuntimeError(f"Step failed ({code}); see {log}")


def ask(question: str) -> str:
    if not sys.stdin.isatty():
        return ""
    try:
        return input(question).strip()
    except EOFError:
        return ""


def main(argv: list[str] | None = None) -> int:
    import plistlib
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--game", type=Path, help=f"{NAME}.exe from the Steam depot (found automatically)")
    p.add_argument("--icon", type=Path, help="your own .icns (default: a Mac-style icon made from the game's icon)")
    p.add_argument("--output", type=Path, default=Path.home() / "Applications" / f"{NAME}.app")
    p.add_argument("--replace", action="store_true", help="move an existing app at --output to the Trash first")
    p.add_argument("--i-own-the-game", action="store_true", help="confirm you own the game on Steam (asked otherwise)")
    a = p.parse_args(argv)
    if sys.platform != "darwin":
        raise ValueError("This builder runs on macOS")
    print(f"buckshot-roulette-mac {VERSION}\nBuilds a Mac app from your own Steam copy of {NAME}. It contains and downloads none of the game.\n"
          f"Buy it: https://store.steampowered.com/app/{APP_ID}/\n")
    if not a.i_own_the_game and ask(f"Do you own {NAME} on Steam? [y/N] ").lower() not in ("y", "yes"):
        raise ValueError("This builder is only for people who own the game (add --i-own-the-game when not interactive)")
    game = a.game or find_depot_exe()
    if not game:
        subprocess.run(["open", "steam://open/console"])
        raise ValueError(f"The Windows game files aren't downloaded yet. Steam's console just opened: type\n"
                         f"    download_depot {APP_ID} {DEPOT_ID}\n"
                         f"press Enter, wait for 'Depot download complete', then run this again.")
    game = game.expanduser().resolve()
    check_exe(game)
    icon = a.icon
    if icon and (not icon.is_file() or icon.suffix.lower() != ".icns"):
        raise ValueError("The icon must be an existing .icns file")
    out = a.output.expanduser().resolve()
    if out.suffix != ".app":
        raise ValueError("--output must end in .app")
    if out.exists():
        if not a.replace and ask(f"{out} exists. Move it to the Trash and replace it? [y/N] ").lower() not in ("y", "yes"):
            raise ValueError("Existing app kept. Choose another --output or add --replace")
        trash = Path.home() / ".Trash" / f"{out.stem} {time.strftime('%Y-%m-%d %H.%M.%S')}.app"
        shutil.move(str(out), trash)
        print(f"Moved the old app to the Trash: {trash.name}")
    out.parent.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(out.parent).free < 2_500_000_000:
        raise ValueError("Not enough free disk space: the build needs about 2.5 GB")
    log = CACHE / "build.log"
    log.write_text("")
    print("1/4 Getting Godot 4.4.1 and GodotSteam 4.10 (cached after the first run)", flush=True)
    godot = unpack(fetch(*GODOT, CACHE / "godot-4.4.1.zip"), CACHE / "godot-4.4.1") / "Godot.app/Contents/MacOS/Godot"
    runtime = fetch_runtime(CACHE / "godot-4.4.1-runtime")
    steam = unpack(fetch(*GODOTSTEAM, CACHE / "godotsteam-4.10.zip"), CACHE / "godotsteam-4.10")
    framework = steam / "addons/godotsteam/osx" / FRAMEWORK
    with tempfile.TemporaryDirectory(prefix="br-build-", dir=out.parent) as scratch:
        work = Path(scratch)
        (work / "cwd").mkdir()  # tools run from an empty folder
        extras = work / "extras"
        (extras / ".godot").mkdir(parents=True)
        (extras / "addons/godotsteam").mkdir(parents=True)
        (extras / ".godot/extension_list.cfg").write_text("res://addons/godotsteam/godotsteam.gdextension\n")
        (extras / "addons/godotsteam/godotsteam.gdextension").write_text(GDEXTENSION)
        if not icon:  # Mac-style icon made from the game's own icon in your copy
            png, iconset = work / "icon.png", work / "icon.iconset"
            run([str(godot), "--headless", "--script", str(ROOT / "tools/icon.gd"), "--", str(game), str(png)], log, cwd=work / "cwd")
            iconset.mkdir()
            for size in (16, 32, 128, 256, 512):
                for scale in (1, 2):
                    name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
                    subprocess.run(["sips", "-z", str(size * scale), str(size * scale), str(png), "--out", str(iconset / name)],
                                   check=True, capture_output=True)
            icon = work / "icon.icns"
            subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(icon)], check=True)
        override = '[rendering]\nrendering_device/driver.macos="metal"\n'  # native Metal, not MoltenVK
        if icon:  # the game sets its own Dock icon at runtime; this makes it use the .icns instead
            shutil.copy2(icon, extras / "mac_icon.icns")
            override += '[application]\nconfig/macos_native_icon="res://mac_icon.icns"\n'
        (extras / "override.cfg").write_text(override)
        app = work / f"{NAME}.app"
        for sub in ("MacOS", "Resources", "Frameworks"):
            (app / "Contents" / sub).mkdir(parents=True)
        print("2/4 Copying your game data and adding Steam support", flush=True)
        run([str(godot), "--headless", "--script", str(ROOT / "tools/repack.gd"), "--",
             str(app / f"Contents/Resources/{NAME}.pck"), str(game), str(extras)], log, cwd=work / "cwd")
        if not (app / f"Contents/Resources/{NAME}.pck").is_file():
            raise RuntimeError(f"Copying the game data failed; see {log}")
        print("3/4 Assembling the app", flush=True)
        shutil.copy2(runtime, app / f"Contents/MacOS/{NAME}")
        (app / "Contents/MacOS/launch").write_text(LAUNCHER)
        for exe in ("launch", NAME):
            (app / "Contents/MacOS" / exe).chmod(0o755)
        shutil.copytree(framework, app / "Contents/Frameworks" / FRAMEWORK, symlinks=True)
        if icon:
            shutil.copy2(icon, app / "Contents/Resources/icon.icns")
        (app / "Contents/PkgInfo").write_text("APPL????")
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(app_metadata()))
        shutil.copy2(ROOT / "NOTICE.md", app / "Contents/Resources/Local build notice.txt")
        print("4/4 Signing locally", flush=True)
        run(["codesign", "--force", "--deep", "--sign", "-", str(app)], log)
        run(["codesign", "--verify", "--deep", "--strict", str(app)], log)
        shutil.move(str(app), out)
    print(f"\nDone: {out}\nKeep Steam running when you play. This app contains the game: don't share it.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValueError, RuntimeError, OSError, zipfile.BadZipFile) as error:
        print(f"\nStopped: {error}", file=sys.stderr)
        raise SystemExit(1)
