# Multiplayer check

**No second player needed:** double-click **Test Multiplayer.command** to open a separate local table with three scripted seats. Your seat is named MIKE. Play normally; the other seats take their items and shoot automatically.

This uses the game's existing four-seat test mode with your installed game data. It uses temporary saves, does not initialize Steam, awards no achievements and never changes your installed app or normal progress. Close the test window to finish; temporary game copies and test saves are removed, while logs remain private under `local/multiplayer-tests/`.

It can exercise the multiplayer scene, item distribution, shots, turn changes and deaths. It does **not** test independent client synchronization, Steam matchmaking, invitations or Internet transport. The scripted seats currently shoot randomly and do not use items strategically.

Terminal equivalents:

```sh
python3 scripts/test_multiplayer.py --local
python3 scripts/test_multiplayer.py --smoke
```

The second command runs a bounded automatic test with all four seats scripted and a short fixed setup. A passing result requires multiple shots and a death; simply closing the visible test is not reported as a passed match.

## Real Steam check

For the original online checklist, run:

```sh
python3 scripts/test_multiplayer.py
```

Use a second player on another computer with their own Steam account and owned copy of the game. Allow about 10–15 minutes. A Windows player can also help check cross-platform play.

The script opens the installed Mac port, or uses it if already running. It walks you through lobby joining, overlay/invites, synchronized gameplay, round transitions, and leaving/rejoining. Enter pass, fail or skip for each check. This is a guided manual test, not simulated network coverage.

Results and available logs stay under `local/multiplayer-tests/` (ignored by Git). Steam, ownership checks, normal saves and achievements remain active. The script never closes the game. Stop it with Ctrl+C to save partial results. A copied log from an already-running game can include events from before the test.

Review logs before sharing: they can contain Steam/player identifiers. Successful local checks do not prove multiplayer works; both players must verify the actual match. Skipped or unfinished checks remain unverified.
