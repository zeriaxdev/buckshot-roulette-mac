# Testing

## Automated checks

```sh
python3 -m unittest discover -s tests
python3 scripts/check_no_game_files.py
```

The unit tests cover exe validation and the app's Info.plist. The game-file check runs on every push and on the release ZIP, and blocks anything from the game.

With Godot 4.4.1 available, run the synthetic geometry check from an empty working directory:

```sh
godot --headless --script /absolute/path/to/tests/table_geometry.gd -- /absolute/path/to/tools/screen_fit.gd
```

It checks six representative table parts: geometry, materials and names survive, shared sources stay unchanged, repeated fitting does not rebuild meshes, and unrelated meshes and LODs are retained. This check also runs in CI and contains no game data.

## Table geometry regression, 18 November 2026

- An offline copy of the owner's v2.2.0.6 scene reproduces the rectangular seam on Godot 4.4.1 with both Metal and Vulkan. The same scene is smooth on Godot 4.1.4/Vulkan.
- Godot 4.8 beta3/Metal still shows the seam. Upgrading the engine alone does not fix it.
- Rebuilding only the player's briefcase panel from its existing mesh arrays removes the seam on Godot 4.4.1/Metal and Vulkan, including a second camera position on Metal. That alone leaves false gaps along the front and right table edges.
- Rebuilding the static table body, compartments and edge/detail meshes removes the marked front-left gap, front-edge line, right-edge slit and counter-side defect in a matched Godot 4.4.1/Metal render. Camera and light values were fixed for comparison with Godot 4.1.4/Vulkan. Lights and materials are not modified by the fix; full visual parity is not established.
- Disabling mesh LOD does not fix it. The panel has no stored LODs; the precise engine-side conversion fault has not been isolated.
- These scene renders use a separate save directory and test-only Steam stubs. They do not verify multiplayer, controller input or a full playthrough. The installed app and real saves were not changed.
- The signed candidate contains all 3,572 original depot files. Hash comparison finds only the three expected script/class-cache changes and five Mac additions; every original scene, texture, model and audio file is byte-identical. This proves packaging preservation, not complete rendering parity.
- A stock Godot 4.1.4/Vulkan control without the visual helper and repaired 4.4.1/Metal and Vulkan reach the same first playable turn. Camera transform, FOV, visible light values and environment settings agree. Four table regions differ by at most 0.02% in mean linear luminance.
- Six views were compared against that control: bathroom, lobby, playable table, dealer, health counter and a controlled four-item layout. Staged snapshots align active animation phases. At least 99.65% of pixels are within two 8-bit RGB levels, with mean linear-luminance differences of 0.24% or less. This is a representative scene check, not coverage of every scene or multiplayer state.

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

## Discord presence

The live local RPC test accepted Buckshot's application ID 1225535693791432814, returned the name Buckshot Roulette with Playing activity type, and acknowledged clearing after a bounded real-game session. No executable rename, steam_appid.txt addition or Discord SDK library was needed. The installed build was unchanged during that protocol trial.

The packaged helper's Universal 2 artifact and fake-client protocol tests pass locally. Tests cover fragmented replies, real PID association, ping/pong, parent-exit cleanup and oversized frames. The combined signed app starts the helper automatically after real Steam initialization. The helper logs Discord acknowledgement and exits with the game; the tested update is installed with a verified backup, preserving save hashes and the custom icon. A fresh launch through original Steam AppID 2835570 also starts the installed helper and both processes exit normally. Thirty combined Python checks pass. ScreenCaptureKit error -3811 prevents UI inspection; the visible Play-button color and verified badge remain unobserved. Existing texture/resource cleanup errors still appear on game exit.

The user later confirmed the original Steam entry's green Play button and removal of the incorrect 32-bit warning. That Steam configuration is a separate local experiment, not a shipped installer feature. The user also confirmed that Discord's Added Games list did not detect the port. On 18 November 2026, the public Discord detection catalog contained only a `win32` executable for application 1225535693791432814 and no macOS executable. The presence helper does not solve verified game detection; a matching Discord-side detection entry is still missing.
