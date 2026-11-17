# Buckshot Roulette for macOS

An unofficial native Mac version of [Buckshot Roulette](https://store.steampowered.com/app/2835570/), built on your Mac from **your own Steam copy**. Runs natively on Metal. Steam achievements, the Steam overlay (Shift+Tab), Invite Friends, online lobbies and PlayStation controllers work.

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Updating](#updating)
- [What it changes](#what-it-changes)
- [Ownership](#ownership)
- [Where your files are](#where-your-files-are)
- [Troubleshooting](#troubleshooting)
- [Known limits](#known-limits)
- [Unofficial project](#unofficial-project)
- [License](#license)

## Background

Buckshot Roulette is only released for Windows. Under the hood it's a Godot 4.1 game, and Godot runs natively on macOS. This repository contains a builder that takes the Windows game files Steam downloads for your account and runs them on the official Godot 4.4.1 macOS runtime, which renders with Metal and reads controllers through Apple's GameController framework, with Steam support added.

No part of the game is in this repository, and the builder doesn't download the game either. You need to own it on Steam. Please buy it: Mike Klubnika deserves every bit of support.

## Install

You need a Mac, Steam signed in to the account that owns the game, and Python 3 (macOS asks to install it the first time if it's missing).

1. **Get the Windows game files.** Open Steam's console by pasting `steam://open/console` into your browser's address bar, then type this and press Enter:

   ```
   download_depot 2835570 2835572
   ```

   Wait until it says `Depot download complete` (about 800 MB). Steam only allows this for accounts that own the game.

2. **Get this builder.** On this repository's page click the green **Code** button, then **Download ZIP**, and extract it.
3. **Double-click `Install Buckshot Roulette.command`.** If macOS blocks it, open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. Answer the questions; press Enter to skip the custom icon.
4. **Play.** Open **Buckshot Roulette** from your home **Applications** folder, with Steam running.

The first build downloads Godot 4.4.1 (about 230 MB) and GodotSteam 4.10 (12 MB) from their official releases, checks them against fixed SHA-256 hashes, and keeps them in `~/Library/Caches/buckshot-roulette-mac`. Later builds take about 10 seconds.

From Terminal instead: `python3 build.py`. Options: `--icon file.icns`, `--output path.app`, `--replace`, `--game path/to/Buckshot\ Roulette.exe`, `--i-own-the-game` (no questions).

## Updating

When Steam updates the game, run `download_depot 2835570 2835572` again, then run the installer and answer **y** to replace the old app. The old app goes to the Trash; your saves are kept.

## What it changes

The game's own files are copied unchanged. The builder adds:

| Addition | Why |
| --- | --- |
| GodotSteam extension | The Windows exe has Steam built in; on Mac it comes from the official GodotSteam plug-in |
| Ownership check in `scripts/Steam.gd` | The game quits with a message unless Steam is running, signed in, and your account owns Buckshot Roulette |
| Godot 4.4 compatibility | `MP_ItemResource_User.gd` stops exporting four Node fields that are never set (Godot 4.4 forbids that in a Resource), and the script class list gets the two keys 4.4 expects |
| `override.cfg` | Selects the native Metal renderer, and with a custom icon keeps it in the Dock |
| A small `launch` script inside the app | Starts the game the way Steam starts its own games (same environment, Metal hook, overlay library), so Shift+Tab and Invite Friends work |

No menus, scenes, text or gameplay are changed.

## Ownership

- The builder only works with game files from Steam's depot, which Steam only gives to owners.
- It asks whether you own the game, like other fan ports do.
- The built app checks with Steam at every start that your account has a licence for Buckshot Roulette (`ISteamApps::BIsSubscribedApp`), and quits otherwise.

This is a courtesy check, not DRM: anyone can edit a local build. The app it makes contains the game, so **never share the built app**. Share this repository instead.

## Where your files are

- App: `~/Applications/Buckshot Roulette.app`
- Saves and settings: `~/Library/Application Support/Godot/app_userdata/Buckshot Roulette/`. The game has no Steam Cloud, so saves stay on this Mac.
- Builder downloads and log: `~/Library/Caches/buckshot-roulette-mac/`

## Troubleshooting

- **"must be owned on Steam"**: start Steam, sign in to the account that owns the game, then open the game again.
- **Builder says the game files aren't downloaded**: do step 1 of [Install](#install). It looks in Steam's default library folder; for another location pass `--game`.
- **Checksum mismatch**: a download was damaged or changed. Delete `~/Library/Caches/buckshot-roulette-mac` and try again. If it keeps happening, open an issue.
- **Anything else**: open an issue and attach `~/Library/Caches/buckshot-roulette-mac/build.log`.

## Known limits

- In Steam's library the game still shows **Install**, not Play, because Valve ships no Mac version. Start the game from Applications; Steam still shows it as running and tracks playtime and achievements.
- The game renders at its original 960×540 and scales to the window or screen, as on Windows.
- Built and tested on Apple Silicon. Builds are signed locally, not notarized by Apple.
- Not tested yet: a full online match between Mac and Windows players, Xbox and Switch controllers.

## Unofficial project

Not made by, endorsed by or affiliated with Mike Klubnika, Critical Reflex or Valve. See [NOTICE.md](NOTICE.md).

## License

The builder is MIT licensed: see [LICENSE](LICENSE). The game, Godot, GodotSteam and the Steamworks SDK keep their own licenses.
