# macOS fullscreen presentation helper

Native macOS fullscreen leaves a camera/menu-bar row outside the game window. Include Notch Area instead uses a borderless window covering the full display. This small GDExtension hides the game's menu bar and Dock while that window is active and restores normal presentation when focus leaves or the window returns to normal size. It also forwards native Space-transition state through a process-local environment flag; the screen helper waits for completion before changing window style.

`presentation.mm` is this project's MIT-licensed code. The checked-in Universal 2 framework contains only that code, so installing the port does not require a compiler. It contains no game files, Godot engine binary or Steam SDK. The builder signs it together with the user's local app.

To rebuild with Xcode command-line tools installed:

```sh
python3 tools/native/build.py
```

The adjacent `gdextension_interface.h` comes unchanged from Godot 4.4.1, commit `49a5bc7b616bd04689a2c89e89bda41f50241464`, under the MIT license printed in the header. Both arm64 and x86_64 slices are built from the same source. Physical display testing is performed locally; inspecting the binary's architectures alone does not verify rendering.
