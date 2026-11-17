# Buckshot Roulette for macOS

Play [Buckshot Roulette](https://store.steampowered.com/app/2835570/) natively on your Mac, built from your own Steam copy. It renders with Metal, and Steam achievements, the Shift+Tab overlay, Invite Friends, online lobbies and PlayStation controllers all work.

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

None of the game is in this repository, and the builder doesn't download it either. You need to own it on Steam. Mike Klubnika made a great game, so please buy it.

## Install

You need Steam signed in to the account that owns the game, and Python 3. If Python is missing, macOS offers to install it the first time.

1. **Download the Windows game files.** Paste `steam://open/console` into your browser's address bar to open Steam's console, type this and press Enter:

   ```
   download_depot 2835570 2835572
   ```

   Wait for `Depot download complete` (about 800 MB). Steam only lets accounts that own the game do this.

2. **Download this builder.** Get the ZIP from the [latest release](https://github.com/zeriaxdev/buckshot-roulette-mac/releases/latest) and extract it.
3. **Double-click `Install Buckshot Roulette.command`.** If macOS blocks it, go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**. Answer the questions. Press Enter to skip the custom icon.
4. **Play.** Open **Buckshot Roulette** from the **Applications** folder in your home folder. Keep Steam running.

The first build downloads Godot 4.4.1 (about 230 MB) and GodotSteam 4.10 (12 MB) from their official releases and checks each against a fixed SHA-256 hash. They stay cached in `~/Library/Caches/buckshot-roulette-mac`, so later builds take about 10 seconds.

Prefer Terminal? Run `python3 build.py`. Options: `--icon file.icns`, `--output path.app`, `--replace`, `--game path/to/Buckshot\ Roulette.exe`, and `--i-own-the-game` to skip the questions.

## Updating

When Steam updates the game, run `download_depot 2835570 2835572` again, then run the installer and answer **y** to replace the app. The old app goes to the Trash. Your saves stay where they are.

## What the builder changes

The game's files are copied as they are. The builder adds:

| Addition | Why |
| --- | --- |
| GodotSteam extension | The Windows exe has Steam compiled in. On Mac it comes from the official GodotSteam plug-in. |
| Ownership check in `scripts/Steam.gd` | The game quits with a message unless Steam is running, you're signed in, and your account owns Buckshot Roulette. |
| Godot 4.4 fixes | `MP_ItemResource_User.gd` stops exporting four Node fields that nothing sets (4.4 doesn't allow that in a Resource), and the script class list gets the two keys 4.4 expects. |
| `override.cfg` | Picks the Metal renderer, and keeps your custom icon in the Dock if you chose one. |
| A small `launch` script | Starts the game with the same environment Steam gives its own games, which is what makes Shift+Tab and Invite Friends work. |

Menus, scenes, text and gameplay stay exactly as they are.

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
- **The builder says the game files aren't downloaded**: do step 1 of [Install](#install). The builder looks in Steam's default library folder. If yours is elsewhere, pass `--game`.
- **Checksum mismatch**: a download got damaged or changed. Delete `~/Library/Caches/buckshot-roulette-mac` and try again. If it keeps happening, open an issue.
- **Anything else**: open an issue and attach `~/Library/Caches/buckshot-roulette-mac/build.log`.

## Known limits

- Steam's library still shows **Install** instead of Play, because Valve ships no Mac version. Start the game from Applications. Steam still shows you as playing and tracks playtime and achievements.
- The game draws at 960×540 and scales up to your window or screen, same as on Windows.
- Built and tested on Apple Silicon. Builds are signed on your Mac, not notarized by Apple.
- Not tested yet: a full online match between Mac and Windows players, and Xbox or Switch controllers.

## Unofficial project

Not made by, endorsed by or affiliated with Mike Klubnika, Critical Reflex or Valve. See [NOTICE.md](NOTICE.md).

## License

The builder is MIT licensed, see [LICENSE](LICENSE). The game, Godot, GodotSteam and the Steamworks SDK keep their own licenses.
