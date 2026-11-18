# Testing

## Automated checks

```sh
python3 -m unittest discover -s tests
python3 scripts/check_no_game_files.py
```

The unit tests cover exe validation and the app's Info.plist. The game-file check runs on every push and on the release ZIP, and blocks anything from the game.

## Verified on macOS 27.0.1, Apple M5, game v2.2.0.6

- A fresh install from the public 1.0.0 release ZIP, with an empty download cache, builds in about 11 seconds. The app's signature verifies.
- Answering **n** to the ownership question stops the builder; **y** builds.
- The ownership check passes for an owning account. Steam reports no licence (`isSubscribedApp` false) for a game the account doesn't own and for a made-up app id, so a non-owner gets refused.
- The game starts on Godot 4.4.1 with Metal, Steam initialises, and the game's scripts load without errors.
- Steam achievements, the Shift+Tab overlay, the Invite Friends dialog, public lobbies and a DualShock 4 controller work.
- Hold Escape exits a run.
- The generated icon shows in Finder and stays in the Dock while playing.

## Performance

Main menu, 30 seconds each, same build:

| | Metal | MoltenVK (Vulkan) |
| --- | --- | --- |
| CPU | 3.4% | 11.4% |
| Memory | 375 MB | 385 MB |
| FPS | about 145 | 120, locked to the display |

A short test on one scene, not a benchmark.

## Not verified

- A full online match between Mac and Windows players
- Xbox and Switch controllers
- Intel Macs
- Steam libraries outside the default folder (use `--game`)

## Fill Screen controller projection

`tests/screen_fit_rays.gd` compares actual Camera3D ray directions before and after expansion. The old code fails at 960x600; the coordinate fix passes 12 comparisons across 960x540, 960x600 and 1200x600. It exercises item-slot-like positions and the centre.

Run with the cached Godot 4.4.1 editor, an empty project directory, `--headless --path EMPTY --script tests/screen_fit_rays.gd -- ABSOLUTE_PATH_TO_tools/screen_fit.gd`. A fresh local build with the updated single-player and multiplayer raycast patches signs and verifies. Physical DualShock item pickup still needs a play check.

## Table-panel rendering regression

A separate test copy reproduces the rectangular dark seam at the player-facing table panel. It appears on Godot 4.4.1 with Metal and Vulkan, with Fill Screen on or off, and remains when scene shadows are disabled. The same table view is clean under Godot 4.1.4/Vulkan. This narrows the defect to an engine-upgrade compatibility regression; no visual workaround has been applied. The screenshots and exploratory fixtures remain private temporary files.

## Mac-page layout and navigation

`tests/mac_menu.gd` runs against an extracted, SDK-disabled test fixture with a separate save directory. Deferred scene/helper attachment avoids the earlier fixture-only `Parent node is busy` error. The real menu passes opening MAC with controller focus, reaching all four controls, toggling each setting once without changing the original greyscale setting, and returning through both cancel and Return. Labels share a rendered left edge at the top of the page. An offscreen Metal screenshot was inspected; the inherited label pivots are reset so the text stays in its intended column. Notch clearance remains automatic and is explained on the page.

The fixture still reports resource-cleanup warnings at exit; this is not a clean full-game shutdown test. Physical DualShock input and the actual display's notch remain manual checks. Private screenshots and game fixtures are not included in the repository.
