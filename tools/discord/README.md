# Discord presence helper

`discord-presence` is this project's Universal 2 executable, built from `presence.mm` under the repository's MIT license. It contains no game data or third-party SDK binary. Rebuild it with Xcode command-line tools:

```sh
python3 tools/discord/build.py
```

The locally patched Steam startup launches it only after the ownership check succeeds, passing the real game PID. It connects to the running Discord desktop client's local socket and sends Playing with application ID 1225535693791432814. The protocol follows Discord's published RPC handshake and SET_ACTIVITY framing. It handles ping, reconnects after a client disconnect, and clears its activity when the game exits. No account tokens are read. Discord's sharing settings determine visibility.

A separate process keeps socket errors and delays outside the game thread. If Discord is absent, only the helper retries; the game continues. The game executable and bundle entry point keep their existing names. No Discord GDExtension is required for this small integration.

The live protocol trial returned application ID 1225535693791432814, name Buckshot Roulette and activity type Playing, and acknowledged clearing. This publishes profile activity; it does not register the executable in Discord's Added Games list or grant verified detection. On 18 November 2026, Discord's [public detection catalog](https://discord.com/api/v9/applications/detectable) listed only `buckshot roulette_windows/buckshot roulette.exe` with OS `win32` for this application, with no macOS entry. The user confirmed that the Mac game was absent from Added Games. A matching macOS detector requires a Discord-side catalog update, not an executable rename or another RPC call. The helper is about 86 KB; it is not a bundled Discord SDK. Intel hardware remains untested.

Tests use a fake socket in a private temporary directory and never contact the real Discord client. They check fragmented frames, activity PID/timestamp, ping/pong, cleanup after the simulated game exits, and an oversized reply.

Protocol references: [connection and handshake](https://github.com/discord/discord-rpc/blob/master/src/rpc_connection.cpp), [local socket](https://github.com/discord/discord-rpc/blob/master/src/connection_unix.cpp), [activity framing](https://github.com/discord/discord-rpc/blob/master/src/serialization.cpp). Discord's old RPC library is deprecated; no copy of that library is shipped. This client uses the protocol currently accepted by the installed desktop app, and future protocol changes may require an update.
