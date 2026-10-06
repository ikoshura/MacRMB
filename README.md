# RMB

**Mouse panning and mouse-button binding for Switch emulators on macOS** — the [IamSanjid/RMB](https://github.com/IamSanjid/RMB) C++ engine used as-is, driven by a Swift interface designed after [NotProton](https://github.com/NotProtonNot/NotProton)'s sidebar UI (with permission banners and stable error codes à la [MetalGoose](https://github.com/Stallion77RepoOfficial/MetalGoose)).

Panning behavior is upstream's original algorithm: a 1 ms cursor poll thread, yuzu-derived mouse smoothing, radial deadzone math, and keyboard simulation through a Native abstraction. Swift supplies only the settings UI, the ⌥⌘P hotkey, and the configurable pin position.

## Features

- **Original RMB C++ engine** (`Vendor/RMB/`, ~2.2 k lines): `Mouse` smoothing → `NpadController` deadzone math → `KeyboardManager` queues → `Native` key simulation, on its own 1 ms worker thread
- **⌥⌘P** global hotkey (Carbon — never steals focus from the game)
- Upstream analog parameters: sensitivity, radial deadzone, range, threshold, axis offsets — same values/semantics as original RMB
- **Cursor auto-hide** exactly like upstream's mechanism (the same `SetsCursorInBackground` technique as the Raycast cursor-toggle extension): **hides immediately when panning starts**, re-asserted every 2.5 s while panning or idle over the target, restored on stop/quit/crash
- Mouse-button → key bindings (left/right/middle), for ZL/ZR/A/B
- Target tracking by window title **or** app name, with a **Detect** button
- NotProton-style interface: sidebar `NavigationSplitView` (Status / Panning / Bindings), tone-dotted status rows with trailing actions, grouped forms
- Menu bar item, `⌘1/2/3` pane shortcuts, commands menu
- Stable error codes (`RMB-UI-001`, `RMB-CUR-001`, …) shown as coded alerts

## Requirements

- macOS 13.0+ (developed/tested on macOS 27)
- An emulator with keyboard input mapping (Ryujinx/Ryujinx forks, etc.)
- Permissions: **Accessibility**, **Input Monitoring**, and **Allow Events to Your Mac** (Post-Event) — the engine requests all three on first launch

## Build

```sh
xcodegen generate          # regenerates RMB.xcodeproj from project.yml
xcodebuild -project RMB.xcodeproj -scheme RMB -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build
xcodebuild -project RMB.xcodeproj -scheme RMB -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build test   # 19 unit tests
open build/Build/Products/Debug/RMB.app
```

Self-test for the cursor-hide path (exit 0 = works on your OS):

```sh
build/Build/Products/Debug/RMB.app/Contents/MacOS/RMB --check-cursor
```

## First-time setup

1. Launch RMB → grant the three prompts it asks for (**Accessibility**, **Input Monitoring**, **Allow Events to Your Mac**). If the orange banner shows, use *Grant Access* and enable RMB under **System Settings → Privacy & Security**.
2. In your emulator, bind **Right Stick** to **I/K/J/L** — RMB's default (change it in the *Bindings* pane if yours differ). Optionally bind ZL/ZR/buttons to keys like `Q`/`E`/`F`.
3. In the *Status* pane, set **Target** (*Detect* fills it from the frontmost window) and mirror any mouse-button bindings in *Bindings*.
4. Press **⌥⌘P** — the emulator is auto-focused, the cursor hides after 2.5 s idle (re-asserted while it stays hidden), and mouse movement drives the camera.

## Configuration

Stored as JSON in `~/Library/Application Support/RMB/config.json`:

```jsonc
{
  "version" : 2,
  "targetName" : "Ryujinx",
  "sensitivity" : 10,        // 1–30 (upstream scale)
  "deadzone" : 0.15,         // 0–0.9 radial deadzone
  "range" : 0.95,
  "threshold" : 0.5,         // 0–1 axis press threshold
  "stickOffsetX" : 0, "stickOffsetY" : 0,
  "hideCursor" : true,
  "autoFocus" : true,
  "bindMouseButtons" : true,
  "persistentKeyPress" : false,
  "directions" : { "up" : 34, "down" : 40, "left" : 38, "right" : 37 }, // I/K/J/L
  "bindings" : { "2" : 49 }   // mouse button index → key (middle → Space)
}
```

Right-stick keys are editable in **Bindings → Right Stick keys** (or in the JSON) — just bind the same keys in your emulator. Analog parameters live under **Panning**. Legacy configs (v0/v1) migrate automatically on first load.

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

Codes are stable identifiers and are never renumbered; gaps are reserved.

## Architecture

```
Vendor/RMB/            original RMB C++ engine (vendored, minimally patched)
├── EngineDriver.cpp   our C driver replacing upstream's GLFW/ImGui Application
├── rmb_engine.h       extern "C" API consumed by Swift via bridging header
├── mouse / npad_controller / keyboard_manager / Config   upstream core (as-is)
└── macos/             upstream Native implementation (event tap, CGS cursor hide)
Sources/
├── App/               RMBApp (NotProton-style Window + commands), AppDelegate, AppModel bridge
├── Views/             RootView (sidebar), StatusView + StatusRow, PanningView, BindingsView
├── Core/              Permissions, HotkeyManager (Carbon), FocusMonitor, WindowLocator, ErrorCodes
└── Settings/          Config v2 + ConfigStore (JSON, migrations), KeyCodeCatalog
Tests/RMBKitTests/     15 unit tests (config round-trips, migrations, focus matching, anchors)
```

Three targets: `RMBCore` (C++20 static library with the vendored engine), `RMBKit` (Swift framework, testable without the UI), `RMB` (the app).

## Notes & limitations

- **Mechanism**: RMB never injects into the emulator — it holds keyboard keys, relying on the emulator's own input configuration (same approach as the original RMB).
- The engine's cursor hiding uses the **undocumented** `SetsCursorInBackground` connection property (same as upstream); both hide and show are exercised by `--check-cursor`, and macOS restores the cursor itself if the app dies.
- Not Mac App Store eligible (undocumented API + input injection). Built to run locally/notarized outside the MAS.
- The engine's event tap only swallows its own registered hotkeys; every other key and click passes through untouched.

## Credits

- [IamSanjid/RMB](https://github.com/IamSanjid/RMB) — the original C++ engine, vendored and driven from Swift (unlicensed; fine for personal use, **don't redistribute** without the author's permission — consider asking them to add a license)
- [NotProtonNot/NotProton](https://github.com/NotProtonNot/NotProton) — UI structure and status-row design language (GPL-3.0)
- [Stallion77RepoOfficial/MetalGoose](https://github.com/Stallion77RepoOfficial/MetalGoose) — permission banner / error-code conventions (GPL-3.0)
- [Dhaiwat10/raycast-mouse-cursor-toggle](https://github.com/Dhaiwat10/raycast-mouse-cursor-toggle) — background cursor-hide technique reference (MIT)
- [cameron314/concurrentqueue](https://github.com/cameron314/concurrentqueue) — lock-free queue used by the engine (MIT)

## License

MIT — see [LICENSE](LICENSE).

