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

The runner extracts a temporary test copy of the installed PCK, applies this checkout's runtime fixes, and uses unique disposable saves. It never replaces the installed app. It suppresses achievement writes during scripted gameplay and keeps private failure logs in `local/test-logs/`. Temporary game files and test saves are removed when the run finishes.

- `--scenario lifecycle`: sub-second scene-removal checks for the three repeating light/display loops.
- `--scenario death`: jumps straight to lethal dealer shots, with 1 HP/1 damage, 2 HP/2 damage, and the ordinary death/restart path. Each case waits eight simulated seconds plus scene loading.
- `--baseline`: skips the proposed patches, to verify that the tests detect the original failures. Use an unpatched installed build.
- `--godot path/to/runtime`: tests the release runtime instead of the default cached editor. Release and editor are both needed: the editor reports script locations, while release can crash on a null timer call.

The runner fails on script errors, null-object engine errors, crashes, wrong final scenes and a 45-second per-process timeout. The Python checks also exercise path containment, truncated PCK data, error detection and timeouts. Runtime tests require the owner's game and stay local; CI runs only the asset-free Python checks.

These are transition regressions, not a complete playthrough or a rendering/controller test. The full scenarios start from the table rather than driving the introductory flow.

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
- Latest release run: 8 of 9 full death scenarios passed. The remaining process crashed in AudioDriverDummy/AudioServer, a different native failure. This is unresolved; do not treat the suite as an all-green stability certification.
- Rendering and physical controller regressions are still separate checks.
