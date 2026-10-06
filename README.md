# RMB

**Mouse panning and mouse-button binding for Switch emulators on macOS** — a Swift-native reimplementation of [IamSanjid/RMB](https://github.com/IamSanjid/RMB)'s idea, built with the app architecture and UI language of [MetalGoose](https://github.com/Stallion77RepoOfficial/MetalGoose).

While panning is active, your mouse is pinned at the emulator window's center: movement past a configurable deadzone holds arrow-key presses (which your emulator maps to the right stick), so you can aim the camera with the mouse — and mouse buttons can be bound to keys like ZL/ZR/A/B. The pinned cursor is hidden so it never distracts.

## Features

- **⌥⌘P** global hotkey toggles panning (raw Carbon hotkey — never steals focus from the game)
- Cursor pinned at the target window's center + X/Y offset, with deadzone, sensitivity, and invert-Y settings
- **Hide cursor while panning** — uses the same undocumented `SetsCursorInBackground` WindowServer property + `CGDisplayHideCursor` as the MIT-licensed Raycast *Mouse Cursor Toggle* extension, so it works while the emulator is frontmost. Restored automatically on deactivate/quit (and by macOS itself if RMB crashes)
- Mouse-button → key bindings (left/right/middle/back/forward)
- Target tracking by window title **or** app name (window titles read via the Accessibility API — no Screen Recording permission needed), with a **Detect** button
- MetalGoose-style UI: grouped settings form, permission banner, stable error codes (`RMB-UI-001`, `RMB-CUR-001`, …) shown as coded alerts
- Menu bar status item with quick enable/disable
- Only one permission needed: **Accessibility**

## Requirements

- macOS 13.0+ (developed/tested on macOS 27)
- An emulator with keyboard input mapping (Ryujinx/Ryujinx forks, etc.)

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

1. Launch RMB → the orange **Accessibility access required** banner appears → *Grant Access* → enable RMB in **System Settings → Privacy & Security → Accessibility** → *Check Again*.
2. In your emulator, bind **Right Stick** to the **arrow keys** (and optionally ZL/ZR/buttons to keys like `Q`/`E`/`F`).
3. In RMB, set **Target** to the emulator's window/app name (*Detect* fills it from the last focused window), and mirror any mouse-button bindings (e.g. Middle → `Q`).
4. Press **⌥⌘P** while the emulator is focused — status turns *Panning*, the cursor hides, and mouse movement drives the camera.

## Configuration

Stored as JSON in `~/Library/Application Support/RMB/config.json`:

```jsonc
{
  "targetName" : "Ryujinx",
  "deadzone" : 12,          // px (after sensitivity) before input starts
  "sensitivity" : 1,        // 0.1–3.0 delta multiplier
  "offsetX" : 0, "offsetY" : 0,  // shifts the pin center from window center
  "invertY" : false,
  "hideCursor" : true,
  "directions" : { "up" : 126, "down" : 125, "left" : 123, "right" : 124 }, // arrow keys
  "bindings" : { "2" : 11 } // mouse button index → virtual key code (here: middle → C)
}
```

`directions` can be edited in the JSON to use WASD or any other keys — just bind the same keys to the stick in the emulator.

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
Sources/
├── App/        RMBApp (SwiftUI scenes + menu bar), AppDelegate, AppModel conductor
├── Views/      SettingsView, PermissionBanner, ConfigComponents (MetalGoose-style UI)
├── Core/       Permissions, HotkeyManager (Carbon), CursorHider (CGS trick),
│               FocusMonitor (AX window titles), WindowLocator, ErrorCodes
├── Input/      EventTap (CGEventTap), PanningController (pin+warp), KeySimulator
│               (CGEvent key posts), PanningMath (pure, unit-tested)
└── Settings/   Config + ConfigStore (JSON), KeyCodeCatalog
Tests/RMBKitTests/   19 unit tests (math, config round-trips, focus matching)
```

`RMBKit` is a framework so the logic is testable without launching the UI.

## Notes & limitations

- **Mechanism**: RMB never injects into the emulator — it holds keyboard keys, relying on the emulator's own input configuration (same approach as the original RMB).
- The cursor-hide capability step uses an **undocumented API** (`SetsCursorInBackground`) that could change in a future macOS release; both call results are checked and surfaced as `RMB-CUR-*` alerts with graceful fallback (panning still works, cursor just stays visible).
- Not Mac App Store eligible (undocumented API + input injection). Built to run locally/notarized outside the MAS.
- CGEventTap is *listen-only*: your real clicks still reach the game.

## Credits

- [IamSanjid/RMB](https://github.com/IamSanjid/RMB) — the original cross-platform concept and approach (unlicensed; this project reimplements the documented behavior in Swift rather than copying code)
- [Stallion77RepoOfficial/MetalGoose](https://github.com/Stallion77RepoOfficial/MetalGoose) — app architecture & UI design language (GPL-3.0)
- [Dhaiwat10/raycast-mouse-cursor-toggle](https://github.com/Dhaiwat10/raycast-mouse-cursor-toggle) — background cursor-hide technique (MIT)

## License

MIT — see [LICENSE](LICENSE).

