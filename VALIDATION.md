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
