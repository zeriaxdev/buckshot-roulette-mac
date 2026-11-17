# buckshot-roulette-mac

Unofficial builder that turns **your own Steam copy** of [Buckshot Roulette](https://store.steampowered.com/app/2835570/) into a native macOS app. Same idea as my Choicer Voicer Mac builder: you supply the game, the repository contains none of it.

## How it works

Steam only ships Buckshot Roulette for Windows. The Windows exe holds the game data (a Godot 4.1 PCK) and has Steam support compiled in. The builder:

1. finds the Windows depot Steam downloaded for your account (or you point it at the exe),
2. copies the game data unmodified into a new PCK,
3. adds the GodotSteam extension so Steam works on macOS,
4. adds an ownership check (below),
5. wraps it in the official Godot 4.1 macOS runtime, signs it locally and verifies the signature.

Nothing is reconstructed or converted, so there are no lost models, textures or translations.

## What is changed in the game

Only these things. **No menus, scenes or UI are changed.**

| Change | Where |
| --- | --- |
| GodotSteam extension registered | `.godot/extension_list.cfg`, `addons/godotsteam/godotsteam.gdextension` added to the PCK |
| Ownership check at startup | `scripts/Steam.gd`, one block after `InitializeSteam()` |
| Dock icon (only with `--icon`) | `override.cfg` and `mac_icon.icns` added to the PCK |
| Nothing else | |

The ownership check quits the game with a native alert unless Steam is running, you are signed in and `Steam.isSubscribed()` says your account owns the app. If you want that message inside the game's own UI instead of a system alert, that is a scene change and needs to be added on purpose.

## Ownership and piracy: what this does and does not do

- The builder asks "Do you own Buckshot Roulette on Steam?" and refuses to run on no. This is an honour check, like the Choicer Voicer builder.
- The game data comes from the depot Steam downloads only for accounts that own the game.
- The built app refuses to start without a Steam licence for the app.
- This deters casual copying. It cannot stop a determined person: anyone can edit a local build. The game's own Windows build already trusts the `SteamAppId` environment variable, so treat this as a courtesy, not DRM.
- The output app contains the game. Never share it.

## Requirements

- macOS, Python 3.9+
- Steam running and signed in, with the Windows depot downloaded for app 2835570
- [Godot 4.1.4 for macOS](https://github.com/godotengine/godot-builds/releases/tag/4.1.4-stable) and its **export templates** (`Godot_v4.1.4-stable_export_templates.tpz`, or `macos.zip` from it)
- The macOS GodotSteam GDExtension for Godot 4.1 from the [GodotSteam releases](https://github.com/GodotSteam/GodotSteam/releases) (4.10 was tested): a folder containing `osx/libgodotsteam.macos.template_release.framework`

## Build

```sh
python3 build.py \
  --godot /Applications/Godot.app \
  --templates /path/to/Godot_v4.1.4-stable_export_templates.tpz \
  --godotsteam /path/to/godotsteam \
  --output "$HOME/Applications/Buckshot Roulette.app"
```

With `--icon`, the app also gets `override.cfg` (sets `application/config/macos_native_icon`) so the Dock keeps your icon while the game runs. The app starts through a small `launch` script that loads Steam's overlay library, the same way Steam does for games it launches, so Shift+Tab works.

Optional: `--game /path/to/"Buckshot Roulette.exe"` if the depot is not found, `--icon /path/to/your.icns` for a custom icon (none is included). Existing outputs are never overwritten. Needs about 3 GB free while building.

Tests: `python3 -m unittest discover -s tests`

## Status

Verified: builds from the owned depot (game v2.2.0.6), signature verifies, boots, Steam initialises with the real app id, the ownership check passes for an owning account.

Verified by the user: custom Dock icon, Steam overlay with Shift+Tab, hold Escape to exit, Steam shows the game as Running.

Not verified: the ownership check refusing a non-owner, invites, controller input, full multiplayer matches, cloud saves, Discord verified-game badge, the Steam library Play button (Steam's own entry still shows Install because Valve ships no macOS depot), window size and aspect ratio.

## Legal

See [NOTICE.md](NOTICE.md). Unofficial fan project, not affiliated with the game's author, Valve or Steam.
