# Testing

## Automated checks

```sh
python3 -m unittest discover -s tests
python3 scripts/check_no_game_files.py
```

The unit tests cover exe validation and the app's Info.plist. The game-file check runs on every push and on the release ZIP, and blocks anything from the game.

## Fast local crash regressions

After building your owned copy, run:

```sh
python3 scripts/test_game.py --repeat 3
```

The runner extracts a temporary test copy of the installed PCK, applies this checkout's runtime fixes when needed, and uses unique disposable saves. It never replaces the installed app. Steam initialization, callbacks and achievement writes are disabled only in that temporary copy. Private failure logs stay in `local/test-logs/`; temporary game files and test saves are removed when the run finishes.

- `--scenario lifecycle`: sub-second scene-removal checks for the three repeating light/display loops.
- `--scenario death`: drives the actual introductory flow to a playable turn before forcing lethal shots, overkill, a 4-to-2 HP nonlethal hit, death/restart and Escape during a pending shot. Restart checks require a new scene instance, not just the same scene filename.
- `--baseline`: skips the proposed patches, to verify that the tests detect the original failures. Use an unpatched installed build.
- `--godot path/to/runtime`: tests the release runtime instead of the default cached editor. Release and editor are both needed: the editor reports script locations, while release can crash on a null timer call.
- `--audio-driver CoreAudio`: tests the native Mac audio backend with the master bus muted and microphone input disabled. The default remains Dummy.

The runner fails on script errors, null-object engine errors, translation-format failures, crashes, wrong outcomes and a 45-second per-process timeout. The Python checks also exercise path containment, truncated PCK data, fixture isolation, error detection and timeouts. Runtime tests require the owner's game and stay local; CI runs the asset-free Python checks and compiles the GDScript regression scripts.

These are transition regressions, not a complete playthrough or a rendering/controller test. Introductory dialogue and waiver signing are marked completed in disposable test state; the original door, round, shell-loading and dealer-shot code still runs.

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

## Current crash-fix evidence

- Unpatched lifecycle test: null-tree errors in BlinkerBranch, BpmLight and PartitionBranch. The release runtime crashed in all three baseline repetitions.
- Guarded loops: lifecycle checks pass in the editor and release runtime.
- Full scenario initially identified a second timer race in TextShaker and a death-scene startup/restart error. The scene-switch patch addresses detachment during timer callbacks and nested startup transitions.
- An earlier direct-shot fixture passed 8 of 9 scenarios and crashed once in AudioDriverDummy/AudioServer. That native failure was distinct from the scene-tree timer crash and has not been explained.
- The revised fixture first reaches a playable turn and disables SDK startup only in its extracted test copy. The stock 4.1.4 control passes all six outcomes. Godot 4.4.1 release passes 30 gameplay cases plus five lifecycle repetitions with no process failures; the earlier audio failure did not reproduce in this run. Native-audio checks and broader coverage are still pending.
- Rendering and physical controller regressions are still separate checks.

## Fill Screen controller projection

`tests/screen_fit_rays.gd` compares actual Camera3D ray directions before and after expansion. The old code fails at 960x600; the coordinate fix passes 12 comparisons across 960x540, 960x600 and 1200x600. It exercises item-slot-like positions and the centre.

Run with the cached Godot 4.4.1 editor, an empty project directory, `--headless --path EMPTY --script tests/screen_fit_rays.gd -- ABSOLUTE_PATH_TO_tools/screen_fit.gd`. A fresh local build with the updated single-player and multiplayer raycast patches signs and verifies. Physical DualShock item pickup still needs a play check.

## Mac-page layout and navigation

`tests/mac_menu.gd` runs against an extracted, SDK-disabled test fixture with a separate save directory. Deferred scene/helper attachment avoids the earlier fixture-only `Parent node is busy` error. The real menu passes opening MAC with controller focus, reaching all five controls, toggling each setting once without changing the original greyscale setting, and returning through both cancel and Return. Labels share a rendered left edge at the top of the page. An offscreen Metal screenshot was inspected; the inherited label pivots are reset so the text stays in its intended column. The notch checkbox toggles and saves its preference; the previous automatic-clearance note is removed. The app opts out of macOS safe-area compatibility scaling, and the helper extends fullscreen content when Fill Screen and Include Notch Area are both enabled. Actual fullscreen/notch coverage still needs a display check.

The fixture still reports resource-cleanup warnings at exit; this is not a clean full-game shutdown test. Physical DualShock input and the actual display's notch remain manual checks. Private screenshots and game fixtures are not included in the repository.

The FPS row now keeps its label on the left and its value in the right-hand control column. The real-menu fixture checks 60, 120 and UNLIMITED, verifies each rendered right edge matches the checkbox column, and keeps the whole row clickable. An offscreen Metal preview was inspected.

## Full-display notch backend

Native fullscreen on this M5 exposes 3024×1898 of the 3024×1964 display. The title-bar flag and a native fullscreen content-size callback do not make the reserved row available. Include Notch Area therefore uses a borderless window covering the display, plus a small asset-free native helper for active-app presentation and Space-transition completion. `OptionsManager.gd` delegates its two window-mode calls to the Mac helper, preserving the original UI controls and their settings.

`python3 scripts/test_native_window.py` creates a synthetic test app with no game data or Steam connection. Both Compatibility and Forward+/Metal runs pass on/off/on, rapid toggles, helper startup during a native transition, colored pixels in both sides of the top row, and exact restoration of the original 960×540 window. Included mode measures position (0,0), size 3024×1964; excluded mode returns to position (0,66), size 3024×1898. The native helper's active-app flags hide the menu bar and Dock; no system preference is changed. A compositor screenshot was unavailable, so these checks establish actual window bounds and rendered viewport pixels rather than a photograph of the physical notch. Intel hardware and packaged-game validation remain pending.

## Discord presence

The live local RPC test accepted Buckshot's application ID 1225535693791432814, returned the name Buckshot Roulette with Playing activity type, and acknowledged clearing after a bounded real-game session. No executable rename, steam_appid.txt addition or Discord SDK library was needed. The installed build was unchanged during that protocol trial.

The packaged helper's Universal 2 artifact and fake-client protocol tests pass locally. Tests cover fragmented replies, real PID association, ping/pong, parent-exit cleanup and oversized frames. The combined signed app starts the helper automatically after real Steam initialization. The helper logs Discord acknowledgement and exits with the game; the tested update is installed with a verified backup, preserving save hashes and the custom icon. A fresh launch through original Steam AppID 2835570 also starts the installed helper and both processes exit normally. Thirty combined Python checks pass. ScreenCaptureKit error -3811 prevents UI inspection; the visible Play-button color and verified badge remain unobserved. Existing texture/resource cleanup errors still appear on game exit.

The user later confirmed the original Steam entry's green Play button and removal of the incorrect 32-bit warning. That Steam configuration is a separate local experiment, not a shipped installer feature. The user also confirmed that Discord's Added Games list did not detect the port. On 18 November 2026, the public Discord detection catalog contained only a `win32` executable for application 1225535693791432814 and no macOS executable. The presence helper does not solve verified game detection; a matching Discord-side detection entry is still missing.
