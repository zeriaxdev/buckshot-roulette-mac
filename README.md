# Buckshot Roulette for macOS

Play [Buckshot Roulette](https://store.steampowered.com/app/2835570/) natively on your Mac, built from your own Steam copy. It renders with Metal, and Steam achievements, the Shift+Tab overlay, Invite Friends, online lobbies and PlayStation controllers all work.

> [!IMPORTANT]
> **Steam version only.** You need to own Buckshot Roulette on Steam. This repo doesn't contain the game and doesn't download it. It turns the copy you already own into a Mac app. It's not a way to play without buying it, so please don't ask for builds or game files. Don't have it yet? [Get it on Steam](https://store.steampowered.com/app/2835570/).

## Contents

- [Why this exists](#why-this-exists)
- [Install](#install)
- [Updating](#updating)
- [What the builder changes](#what-the-builder-changes)
- [Ownership](#ownership)
- [Where your files are](#where-your-files-are)
- [Troubleshooting](#troubleshooting)
- [Known limits](#known-limits)
- [Unofficial project](#unofficial-project)
- [License](#license)

## Why this exists

Buckshot Roulette only comes out for Windows, but it's made in Godot, and Godot runs on macOS. So the builder takes the Windows game files Steam downloads for your account and runs them on the official Godot 4.4.1 Mac runtime, with Steam support added. You get a real Mac app: Metal rendering, controllers through Apple's GameController framework, no Wine or CrossOver.

## Install

You need Steam signed in to the account that owns the game, and Python 3. If Python is unavailable, install it from [python.org](https://www.python.org/downloads/macos/).

1. **Download this builder.** Get the [source ZIP](https://github.com/zeriaxdev/buckshot-roulette-mac/archive/refs/heads/main.zip) and extract it.
2. **Double-click `Install Buckshot Roulette.command`.** If macOS blocks it, go to **System Settings → Privacy & Security** and click **Open Anyway**. Answer the ownership question. If the Windows game files are missing, the installer opens Steam's Console tab and shows the command to paste there. Wait for `Depot download complete`, then press Enter in the installer to continue the same run.
3. **Play.** Open **Buckshot Roulette** from the **Applications** folder in your home folder. Keep Steam running.

Steam downloads about 800 MB from your own account. The installer does not ask for your Steam password or copy anything to your clipboard.

The first build downloads Godot 4.4.1 (about 230 MB) and GodotSteam 4.10 (12 MB) from their official releases and checks each against a fixed SHA-256 hash. They stay cached in `~/Library/Caches/buckshot-roulette-mac`, so later builds take about 10 seconds.

Prefer Terminal? Run `python3 build.py`. Options: `--icon file.icns` (your own icon instead of the generated one), `--output path.app`, `--replace`, `--game path/to/Buckshot\ Roulette.exe`, and `--i-own-the-game` to skip the ownership question.

## Updating

**There are no automatic updates.** The app does not check for updates, download a new builder, or replace itself in the background.

- **Port fixes:** download the latest builder source ZIP and run its installer again. An old installer keeps using its own version of the port.
- **Game updates:** open `steam://open/console` and run `download_depot 2835570 2835572` again. Wait for the download to complete, then run the installer. Existing depot files are reused as-is until you refresh them through Steam.

Answer **y** to replace the app. The working app stays installed until the replacement finishes building and its signature verifies. The old app then goes to the Trash; if the final swap fails, it is restored. Your saves stay where they are.

## What the builder changes

The builder preserves the shipped assets and applies these additions and compatibility patches:

| Addition | Why |
| --- | --- |
| GodotSteam extension | The Windows exe has Steam compiled in. On Mac it comes from the official GodotSteam plug-in. |
| Ownership check in `scripts/Steam.gd` | The game quits with a message unless Steam is running, you're signed in, and your account owns Buckshot Roulette. |
| Godot 4.4 fixes | `MP_ItemResource_User.gd` stops exporting four Node fields that nothing sets (4.4 doesn't allow that in a Resource), and the script class list gets the two keys 4.4 expects. |
| Table geometry compatibility | The Mac helper rebuilds static table parts in memory to remove a dark panel seam and false gaps around the table edges on Godot 4.4. Their vertices, UVs and materials are preserved. |
| Scene-transition fixes | Repeating light/display timers stop after leaving the scene tree. Scene changes are deferred until the current callbacks finish, including the death screen's automatic restart. |
| `override.cfg` | Picks the Metal renderer. |
| A Mac-style icon | Made from the game's own icon in your copy, so it isn't shipped here. |
| A small Mac helper script | Keeps that icon in the Dock while the game runs (the game would swap in its raw PNG). |
| A small `launch` script | Starts the game with the same environment Steam gives its own games, which is what makes Shift+Tab and Invite Friends work. |
| A **MAC** page in Options | First entry in Options (the other entries move down one row, lined up with the main menu). It has **FILL SCREEN 16:10 \*** (experimental, off by default), **FPS LIMIT** (unlimited, 60 or 120) and **SHOW FPS**, built from copies of the game's own menu items. Fill Screen fills a 16:10 screen instead of showing black bars: menus stay centred, the camera keeps its 16:9 width and shows a little more above and below. Saved in `mac_screen.json` next to the game's settings. |

The MAC entry and its page are the only menu changes. Its settings start at the top like Audio/Video, with aligned labels and an experimental INCLUDE NOTCH AREA checkbox. It is off by default and takes effect with Fill Screen in fullscreen; drawing beside the camera housing requires the full-display backend in PR #6. It uses the game's own controls, with explicit controller focus and return paths. The camera and raycast scripts are patched for Fill Screen, including conversion of controller item-target coordinates. Game rules and shipped scene assets are preserved.

## Ownership

- The game files come from Steam's depot, and Steam only hands those to owners.
- The builder asks whether you own the game.
- Every time the app starts, it asks Steam whether your account has a licence for Buckshot Roulette (`ISteamApps::BIsSubscribedApp`) and quits if not.

Anyone can edit a local build, so treat this as a courtesy check rather than DRM. The app you build contains the game: **please don't share it**. Share this repository instead.

## Where your files are

- App: `~/Applications/Buckshot Roulette.app`
- Saves and settings: `~/Library/Application Support/Godot/app_userdata/Buckshot Roulette/`. The game has no Steam Cloud, so saves stay on this Mac.
- Builder downloads and log: `~/Library/Caches/buckshot-roulette-mac/`

## Troubleshooting

- **"must be owned on Steam"**: start Steam, sign in to the account that owns the game, and open the game again.
- **The builder says the game files aren't downloaded**: follow the Steam Console instructions in the installer. The builder looks in Steam's default library folder. If yours is elsewhere, pass `--game`.
- **Checksum mismatch**: a download got damaged or changed. Delete `~/Library/Caches/buckshot-roulette-mac` and try again. If it keeps happening, open an issue.
- **Anything else**: open an issue and attach `~/Library/Caches/buckshot-roulette-mac/build.log`.

## Known limits

- Steam's library still shows **Install** instead of Play, because Valve ships no Mac version. Start the game from Applications. Steam still shows you as playing and tracks playtime and achievements.
- The game draws at 960×540 and scales up to your window or screen, same as on Windows.
- Built and tested on Apple Silicon. Builds are signed on your Mac, not notarized by Apple.
- Fill Screen is experimental. Mac-page focus, all five controls and both return paths pass an isolated real-menu check; physical controller input still needs a play check. Checked on the menu, Options, the MAC page, the loading screen, the multiplayer lobby, bathroom and table; expanded death, win and heaven views remain unverified.
- Not tested yet: a full online match between Mac and Windows players, and Xbox or Switch controllers.

## Unofficial project

Not made by, endorsed by or affiliated with Mike Klubnika, Critical Reflex or Valve. See [NOTICE.md](NOTICE.md).

## License

The builder is MIT licensed, see [LICENSE](LICENSE). The game, Godot, GodotSteam and the Steamworks SDK keep their own licenses.
