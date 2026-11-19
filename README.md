# Buckshot Roulette for Mac

Play [Buckshot Roulette](https://store.steampowered.com/app/2835570/) natively on your Mac. Metal graphics, the Steam overlay, invites, achievements and online lobbies all work, and there's no Wine or CrossOver involved.

> [!IMPORTANT]
> **There are no game files in this download.** It's an installer that takes the copy you already own on Steam and builds a Mac app from it on your own Mac. Nothing here lets you play without buying the game. Don't have it yet? [Get it on Steam](https://store.steampowered.com/app/2835570/).

## What you need

- Buckshot Roulette in your Steam library, with Steam installed and signed in.
- A Mac with Apple silicon. Intel Macs should work but haven't been tested.
- Python 3. Most Macs already have it; if not, macOS offers to install it the first time, or get it from [python.org](https://www.python.org/downloads/macos/).
- About 3 GB of free space.

## Install

1. Download the newest ZIP from [Releases](https://github.com/zeriaxdev/buckshot-roulette-mac/releases) and unzip it.
2. Double-click **Install Buckshot Roulette.command**. If macOS won't open it, go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. Answer `y` when it asks if you own the game.
4. The first time, the installer opens Steam's console and shows one line to paste there. Paste it, wait until Steam says `Depot download complete` (about 800 MB), then press Enter in the installer.
5. Wait a minute or two. The first build downloads about 250 MB of build tools.
6. Optional: answer `y` to get a **Play** button in Steam. The installer asks you to quit Steam for this step.

That's it. Start the game from Steam if you added the Play button, or from the **Applications** folder in your home folder. Keep Steam running while you play.

Everyone builds their own copy. Don't send people the app you built: it contains the whole game. Send them this page instead.

## The Play button in Steam

Steam lists Buckshot Roulette as Windows-only, so it shows **Install** on a Mac. The installer can change that: it adds a Mac launch option to this one game's entry in Steam's local data and points it at your app. Nothing else in Steam is touched. The overlay, invites, achievements and playtime work either way.

Steam can drop the button when it refreshes the game's data, for example after a game update. Quit Steam and bring it back with:

```sh
python3 steam_entry.py add
```

To remove it, quit Steam and run `python3 steam_entry.py remove`. Run both from the unzipped folder.

## Playing

- **Online:** press Multiplayer in the main menu and invite friends through the Steam overlay (Shift+Tab). Mac players and Windows players use the same lobbies.
- **Practice table:** double-click **Test Multiplayer.command** to play against three bots. It uses separate temporary saves and never touches Steam. More in [MULTIPLAYER_TESTING.md](MULTIPLAYER_TESTING.md).
- **MAC page:** the first entry in Options. It has an FPS limit, an FPS counter, and an experimental **Fill Screen** setting that fills a 16:10 Mac screen instead of showing black bars, optionally including the area beside the notch.

## Updating

There are no automatic updates. The app is built from your own game files, so nothing gets downloaded or replaced in the background.

- **New version of this port:** download the new ZIP and run its installer. Answer `y` to replace the app. Your old app stays until the new one is built and checked.
- **Game update on Steam:** paste the same console line again (`download_depot 2835570 2835572`), wait for it to finish, then run the installer.

Your saves are never touched.

## Uninstall

1. If you added the Play button, quit Steam and run `python3 steam_entry.py remove`.
2. Move `~/Applications/Buckshot Roulette.app` to the Trash.
3. Optional: delete the build tools in `~/Library/Caches/buckshot-roulette-mac`.

Your saves stay in `~/Library/Application Support/Godot/app_userdata/Buckshot Roulette/` in case you come back. The game doesn't use Steam Cloud, so that folder is the only copy.

## Troubleshooting

- **The game says it must be owned on Steam:** start Steam, sign in to the account that owns the game, then open the game again.
- **Terminal says `no such file or directory`** right after you open the installer: your shell asked its own question first and swallowed part of the command (oh-my-zsh's update prompt does this). Double-click the installer again.
- **The installer can't find the game files:** it looks in Steam's default library. If yours is somewhere else, run `python3 build.py --game "/path/to/Buckshot Roulette.exe"`.
- **Checksum mismatch:** a download got damaged. Delete `~/Library/Caches/buckshot-roulette-mac` and try again.
- **Anything else:** [open an issue](https://github.com/zeriaxdev/buckshot-roulette-mac/issues) and attach `~/Library/Caches/buckshot-roulette-mac/build.log`.

## What the installer changes

The game's scenes, models, textures and audio stay exactly as shipped. The installer adds:

- **Steam support** from the official GodotSteam plug-in, since the Windows version has Steam built in.
- **An ownership check:** every time the game starts, it asks Steam whether your account owns Buckshot Roulette, and quits if not. Anyone can edit a local build, so this is a courtesy check, not DRM.
- **Godot 4.4 fixes** for a few scripts, the table's rendering and some crashes when scenes change. The game was made with Godot 4.1, which has no native Metal renderer.
- **The MAC page** in Options. It's the only menu change.
- **Discord status:** Discord shows you as playing Buckshot Roulette.
- **A Mac-style icon** made from the game's own icon in your copy.

Prefer Terminal? `python3 build.py --help` lists the options, such as `--output` for a different install location and `--steam-play` to add the Play button without being asked. [VALIDATION.md](VALIDATION.md) lists what has been tested and how.

## Known limits

- Tested on Apple silicon only.
- Your build is signed on your own Mac, not notarized by Apple.
- Fill Screen is experimental. Some screens, such as the death and win screens, haven't been checked with it yet.
- Discord shows that you're playing, but Discord's Added Games list doesn't recognise the Mac app.
- A full online match between Mac and Windows players hasn't been played yet. Xbox and Switch controllers are untested.

## Unofficial project

Not made by, endorsed by or affiliated with Mike Klubnika, Critical Reflex or Valve. See [NOTICE.md](NOTICE.md).

The installer is MIT licensed, see [LICENSE](LICENSE). The game, Godot, GodotSteam and the Steamworks SDK keep their own licenses.
