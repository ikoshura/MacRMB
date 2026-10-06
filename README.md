<div align="center">

<img width="128" height="128" alt="MacRMB app icon" src="https://github.com/user-attachments/assets/1cd0d7af-f824-430e-9178-772ee3af7561" />

# MacRMB

**Mouse panning and mouse button binding for Switch emulators on macOS.**

Wraps the [IamSanjid/RMB](https://github.com/IamSanjid/RMB) C++ engine with a native Swift settings app.

[Features](#features) · [Requirements](#requirements) · [Build](#build) · [Setup](#first-time-setup) · [Configuration](#configuration) · [Architecture](#architecture)

<br>

<img width="880" alt="MacRMB screenshot" src="https://github.com/user-attachments/assets/74d3c71c-1b7c-4af5-8be6-a792100c2b4d" />

<sub>Sidebar interface with Status, Panning, and Bindings panes</sub>

</div>

<br>

The panning logic is upstream's, including a 1 ms cursor poll thread, mouse smoothing derived from yuzu, radial deadzone math, and keyboard simulation through a Native abstraction. The Swift side only provides the settings UI, the ⌥⌘P hotkey, and the configurable pin position.

## Features

- Upstream RMB C++ engine in `Vendor/RMB/` (about 2.2k lines) covering `Mouse` smoothing, `NpadController` deadzone math, `KeyboardManager` queues, and `Native` key simulation, running on its own 1 ms worker thread
- ⌥⌘P global hotkey (Carbon, so it doesn't take focus from the game)
- Upstream analog parameters (sensitivity, radial deadzone, range, threshold, and axis offsets) with the same values and meaning as the original
- Cursor auto-hide using the same `SetsCursorInBackground` technique as upstream and the Raycast cursor-toggle extension. The cursor hides when panning starts, is re-applied every 2.5 s while panning or idle over the target, and is restored on stop, quit, or crash
- Mouse button to key bindings (left, right, middle), useful for ZL, ZR, A, and B
- Target tracking by window title or app name, with a Detect button
- Sidebar interface with Status, Panning, and Bindings panes, status rows with colored indicators, and grouped forms
- Menu bar item, `⌘1/2/3` pane shortcuts, and a commands menu
- Stable error codes (`RMB-UI-001`, `RMB-CUR-001`, and so on) shown in alerts

## Requirements

- macOS 13.0 or later (developed and tested on macOS 27)
- An emulator with keyboard input mapping (Ryujinx, Ryujinx forks, etc.)
- Accessibility, Input Monitoring, and Allow Events to Your Mac (Post-Event) permissions. The engine requests all three on first launch

## Build

```sh
xcodegen generate          # regenerates RMB.xcodeproj from project.yml
xcodebuild -project RMB.xcodeproj -scheme RMB -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build
xcodebuild -project RMB.xcodeproj -scheme RMB -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build test   # unit tests
open build/Build/Products/Debug/RMB.app
```

You can run a self-test for the cursor-hide path. Exit code 0 means it works on your OS.

```sh
build/Build/Products/Debug/RMB.app/Contents/MacOS/RMB --check-cursor
```

## First-time setup

1. Launch RMB and grant the three permission prompts (Accessibility, Input Monitoring, Allow Events to Your Mac). If the orange banner shows, use Grant Access and enable RMB under System Settings > Privacy & Security.
2. In your emulator, bind Right Stick to I/K/J/L, which is RMB's default (change it in the Bindings pane if yours differ). Optionally bind ZL, ZR, and buttons to keys like `Q`, `E`, and `F`.
3. In the Status pane, set the Target (Detect fills it in from the frontmost window) and mirror any mouse button bindings in Bindings.
4. Press ⌥⌘P. The emulator is focused automatically, the cursor hides after 2.5 s of idle time (and stays hidden while re-applied), and mouse movement drives the camera.

## Configuration

The config is stored as JSON in `~/Library/Application Support/RMB/config.json`.

```jsonc
{
  "version" : 2,
  "targetName" : "Ryujinx",
  "sensitivity" : 10,        // 1-30 (upstream scale)
  "deadzone" : 0.15,         // 0-0.9 radial deadzone
  "range" : 0.95,
  "threshold" : 0.5,         // 0-1 axis press threshold
  "stickOffsetX" : 0, "stickOffsetY" : 0,
  "hideCursor" : true,
  "autoFocus" : true,
  "bindMouseButtons" : true,
  "persistentKeyPress" : false,
  "directions" : { "up" : 34, "down" : 40, "left" : 38, "right" : 37 }, // I/K/J/L
  "bindings" : { "2" : 49 }   // mouse button index to key (middle = Space)
}
```

Right stick keys can be edited under Bindings > Right Stick keys (or in the JSON). Just bind the same keys in your emulator. Analog parameters are under Panning. Older configs (v0 and v1) are migrated automatically on first load.

## Error codes

| Code | Meaning |
|---|---|
| `RMB-UI-001` | ⌥⌘P already registered by another app |
| `RMB-UI-002` | RMB itself is frontmost (switch to the emulator) |
| `RMB-PERM-001` | Accessibility access missing |
| `RMB-IN-001` | Event tap could not be created (grant Accessibility) |
| `RMB-IN-002` | Keyboard event could not be posted |
| `RMB-CUR-001` | WindowServer refused background cursor control |
| `RMB-CUR-002` | `CGDisplayHideCursor` failed |
| `RMB-TGT-001` | No window matched the target name (Detect) |

Codes are stable identifiers and are never renumbered. Gaps are reserved.

## Architecture

```
Vendor/RMB/            upstream RMB C++ engine (vendored, minimally patched)
├── EngineDriver.cpp   C driver replacing upstream's GLFW/ImGui Application
├── rmb_engine.h       extern "C" API used by Swift through a bridging header
├── mouse / npad_controller / keyboard_manager / Config   upstream core, unchanged
└── macos/             upstream Native implementation (event tap, CGS cursor hide)
Sources/
├── App/               RMBApp (window and commands), AppDelegate, AppModel bridge
├── Views/             RootView (sidebar), StatusView + StatusRow, PanningView, BindingsView
├── Core/              Permissions, HotkeyManager (Carbon), FocusMonitor, WindowLocator, ErrorCodes
└── Settings/          Config v2 + ConfigStore (JSON, migrations), KeyCodeCatalog
Tests/RMBKitTests/     unit tests (config round-trips, migrations, focus matching, anchors)
```

Three targets make up the project. `RMBCore` is a C++20 static library with the vendored engine, `RMBKit` is a Swift framework that is testable without the UI, and `RMB` is the app.

## Notes and limitations

- RMB never injects input into the emulator directly. It holds keyboard keys and relies on the emulator's own input configuration, the same approach as the original RMB.
- Cursor hiding uses the undocumented `SetsCursorInBackground` connection property, same as upstream. Both hide and show are exercised by `--check-cursor`, and macOS restores the cursor itself if the app dies.
- Not eligible for the Mac App Store because of the undocumented API and input injection. Intended to run locally or be notarized and distributed outside the store.
- The engine's event tap only swallows its own registered hotkeys. Every other key and click passes through untouched.

## Credits

- [IamSanjid/RMB](https://github.com/IamSanjid/RMB) is the original C++ engine, vendored and driven from Swift.
- [Dhaiwat10/raycast-mouse-cursor-toggle](https://github.com/Dhaiwat10/raycast-mouse-cursor-toggle) is the reference for the background cursor-hide technique (MIT)
- [cameron314/concurrentqueue](https://github.com/cameron314/concurrentqueue) is the lock-free queue used by the engine (MIT)

## License

MIT, see [LICENSE](LICENSE).
