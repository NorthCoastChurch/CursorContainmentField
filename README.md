<img src="docs/icon.png" width="128" alt="Cursor Containment Field icon">

# Cursor Containment Field

A lightweight macOS menu bar utility that prevents the cursor from leaving the primary display. Designed for production and auditorium environments where operators work across multiple monitors and need the cursor reliably contained to the main presentation screen.

Forked from [mouselock](https://github.com/mxrlkn/mouselock) by mxrlkn. Rewritten as a menu bar-only app with a simplified containment model and auto-trigger functionality.

---

## Features

- **Menu bar toggle** — Enable or disable containment instantly from the menu bar icon. No Dock icon.
- **Auto-trigger** — Configure specific apps (e.g. ProPresenter, Resolume) to automatically enable containment when they launch and disable it when they quit.
- **Multi-display aware** — Blocks the cursor from escaping to displays positioned to the left, right, below, or above the primary display.
- **Menu bar stays accessible** — The cursor can always move up into the primary display's menu bar (including an auto-hidden one) so the operator can reach the icon and toggle the app at any time.
- **Always starts disabled** — Containment is off on every launch. It only enables manually or when a configured trigger app is running.

---

## Requirements

- **macOS 13.0 or later** (Ventura+) — required for the SwiftUI `MenuBarExtra` API
- **Xcode** — required to build from source

No special system permissions are required.

---

## Building

```bash
xcodebuild \
  -project CursorContainmentField.xcodeproj \
  -scheme CursorContainmentField \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build
```

Copy to Applications and clear the Gatekeeper quarantine flag:

```bash
rm -rf /Applications/CursorContainmentField.app
cp -R build/DerivedData/Build/Products/Release/CursorContainmentField.app /Applications/
xattr -cr /Applications/CursorContainmentField.app
```

The app is ad-hoc signed (not notarized). The `xattr -cr` step is required on every install to allow macOS to open it without a Developer ID certificate.

---

## Usage

### Menu bar

Click the cursor icon in the menu bar to open the menu:

| Icon | State |
|------|-------|
| Cursor with rays | Containment **on** — cursor is locked to the primary display |
| Plain cursor | Containment **off** — cursor moves freely |

Menu options:
- **Enable / Disable Containment** — manual toggle
- **Settings...** — configure auto-trigger apps
- **Quit** — exit the app

### Auto-trigger apps

Open Settings from the menu to configure apps that should automatically enable containment.

- **Running Apps...** — pick from apps currently running that are installed in `/Applications`
- **From Disk...** — browse for any `.app` not currently running

When any configured app launches (or a running app is added to the list), containment enables. When all configured apps have quit (or are removed from the list), containment disables. The manual toggle always works regardless of auto-trigger state.

---

## Constraints and Known Limitations

**Polling-based containment** — The cursor position is checked at 60 fps. At very high cursor speeds, the cursor may briefly escape the screen edge for one or two frames before being snapped back. This is generally imperceptible in normal use.

**Menu bar zone is intentionally free** — Inside the menu bar strip at the top of the screen only the left and right edges are enforced, so the operator can always reach the menu bar icon without the cursor sliding onto a side display. When a display is attached above the primary, the cursor is snapped back to the top row of the primary display rather than being allowed to escape upward.

**Primary display only** — Containment is based on `NSScreen.screens.first`, the primary display set in System Settings → Displays (not `NSScreen.main`, which follows the key window). In multi-display setups, the cursor is prevented from leaving the bounds of that display.

**Not notarized** — The app is signed ad-hoc. It cannot be distributed through the Mac App Store and will require quarantine removal (`xattr -cr`) on each installation. A Developer ID certificate and notarization would be required for wider distribution.

**macOS 26 beta note** — `NSStatusItem` is non-functional on Darwin 25.x. This app uses `MenuBarExtra` instead and has been tested on macOS 26 beta.

---

## Future Maintenance Notes

These are the most likely failure points if the app stops working after a macOS update.

**`CGWarpMouseCursorPosition` may eventually require Accessibility permission** *(highest risk)*
The app uses `CGWarpMouseCursorPosition` to snap the cursor back in bounds. As of macOS 15 this requires no special permission, but Apple has been progressively locking down low-level input APIs. If a future macOS version gates cursor warping behind Accessibility (or a new dedicated permission), the app will stop containing the cursor with no dialog. `CGWarpMouseCursorPosition` returns a `CGError`, and the app logs the first failure. If containment stops working after an OS update, run `log show --last 10m --predicate 'subsystem == "com.church.CursorContainmentField"'` to look for it, then check System Settings → Privacy & Security → Accessibility and grant access if the app appears there.

**Gatekeeper hardening may change the install steps** *(medium risk)*
The `xattr -cr` quarantine removal step is a supported but increasingly begrudging exception for unsigned binaries. Apple tightens this with each major release, particularly on Apple Silicon. If the install instructions stop working, check Apple's current guidance for running ad-hoc signed apps — the flags or workflow may have changed. Notarization with a Developer ID certificate would eliminate this fragility permanently.

**Primary display coordinate assumptions** *(low risk)*
The containment math assumes `NSScreen.screens.first` represents the primary display with a stable, single-origin coordinate system. This has held since the original Mac. Increasing investment in Stage Manager, virtual displays, and Sidecar introduces more complexity around what "main screen" means. If the cursor is being clamped to the wrong region after an OS update, look at the coordinate math in `setupContainmentTimer()` in `CursorContainmentFieldApp.swift`.

---

## Project Structure

```
CursorContainmentField/
├── CursorContainmentField.xcodeproj/
├── src/
│   ├── CursorContainmentFieldApp.swift   # App entry, AppState, AppDelegate, containment timer
│   ├── ContentView.swift                  # Menu bar view, settings window, running apps sheet
│   ├── Media.xcassets/                    # App icon assets
│   └── CursorContainmentField.entitlements
├── docs/
│   └── icon.png                           # App icon (used in this README)
├── license
└── README.md
```

---

## License

MIT License. Copyright © 2022 mxrlkn, © 2026 Austin Janey. See `license` for details.
