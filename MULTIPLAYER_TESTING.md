# Multiplayer check

Double-click **Test Multiplayer.command** in this folder. Alternatively, run:

```sh
python3 scripts/test_multiplayer.py
```

Use a second player on another computer with their own Steam account and owned copy of the game. Allow about 10–15 minutes. A Windows player can also help check cross-platform play.

The script opens the installed Mac port, or uses it if already running. It walks you through lobby joining, overlay/invites, synchronized gameplay, round transitions, and leaving/rejoining. Enter pass, fail or skip for each check. This is a guided manual test, not simulated network coverage.

Results and available logs stay under `local/multiplayer-tests/` (ignored by Git). Steam, ownership checks, normal saves and achievements remain active. The script never closes the game. Stop it with Ctrl+C to save partial results. A copied log from an already-running game can include events from before the test.

Review logs before sharing: they can contain Steam/player identifiers. Successful local checks do not prove multiplayer works; both players must verify the actual match. Skipped or unfinished checks remain unverified.
