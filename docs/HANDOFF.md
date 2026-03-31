# Macchi Trash Handoff

## Status

This project **builds and launches**, but behavior is currently unstable on some systems.

Observed issue from user:
- Flies often do not appear reliably over Trash when Dock auto-hide is enabled.
- In some previous revisions, flies appeared when they should not (false positives near bottom-right).

Current goal for next session:
- Make detection robust so flies appear only when intended and only over the visible Trash icon.

## Project map

Top-level:
- `Package.swift`: Swift Package config (macOS 13+, executable target).
- `build_app.sh`: builds release binary and wraps into `MacchiTrash.app`.
- `MacchiTrash.app`: generated app bundle (rebuilt often).
- `README.md`: user-facing quick start.
- `docs/HANDOFF.md`: this handoff document.

Source files:
- `Sources/macchi-trash/MacchiTrashApp.swift`
  - SwiftUI app entrypoint with `@NSApplicationDelegateAdaptor`.
- `Sources/macchi-trash/AppDelegate.swift`
  - Main composition root.
  - Wires monitors with `CombineLatest`.
  - Decides `show/hide` for overlay.
  - Owns menu-bar UI and calibration commands.
- `Sources/macchi-trash/CursorTrashProximityMonitor.swift`
  - Poll loop (100ms) for cursor proximity/detection.
  - Publishes `hoverAnchor` (`CGPoint?`).
  - Current detection logic is here and is likely the main bug source.
- `Sources/macchi-trash/DockAccessibilityTrashLocator.swift`
  - Accessibility API helpers for Dock/Trash detection.
  - Attempts exact hit-testing and frame extraction for Trash icon.
- `Sources/macchi-trash/FlyOverlayController.swift`
  - Creates transparent always-on-top panel and positions it at anchor.
- `Sources/macchi-trash/FlyOverlayView.swift`
  - Tiny animated fly drawing with SwiftUI `Canvas`.
- `Sources/macchi-trash/DockGeometry.swift`
  - Fallback geometry model for Dock edge and Trash hot zone.
- `Sources/macchi-trash/TrashMonitor.swift`
  - Watches `~/.Trash` contents.
  - `hasItems` still updates status text, but visibility is currently driven by hover.
- `Sources/macchi-trash/TrashAnchorStore.swift`
  - Persists manual calibration anchor in `UserDefaults`.

## Runtime flow

1. App launches (`MacchiTrashApp` -> `AppDelegate.applicationDidFinishLaunching`).
2. App requests Accessibility prompt (`DockAccessibilityTrashLocator.requestPermissionPromptIfNeeded()`).
3. `TrashMonitor` and `CursorTrashProximityMonitor` start.
4. `CombineLatest(hasItems, hoverAnchor)` drives:
   - menu status text
   - overlay position (`overlayController.setPreferredAnchor(...)`)
   - overlay visibility (`shouldShow = isCursorNearTrash`)
5. Overlay panel is shown/hidden by `FlyOverlayController`.

Important:
- Current show/hide no longer depends on `hasItems`; it depends on cursor hover over Trash logic.

## Current detection design (where bugs likely are)

`CursorTrashProximityMonitor.update()`:
1. Try exact accessibility route:
   - `DockAccessibilityTrashLocator.hoverAnchorIfCursorIsOnTrash(mouseLocation)`
2. If exact route fails, use fallback:
   - infer screen + dock geometry
   - require cursor near dock edge
   - require cursor in trash hot zone
   - use fallback anchor
3. If manual calibration exists:
   - use distance from manual anchor + near-edge condition

Likely problem areas:
- Coordinate conversion and AX hit-testing reliability (`AXUIElementCopyElementAtPosition`).
- `currentVisibleTrashFrame()` heuristic picking wrong element in Dock AX tree.
- Fallback thresholds (`near edge` band and trash zone dimensions) may be too strict/loose.
- Dock auto-hide reveal timing.

## How to run

### Dev run

```bash
cd /Users/harshvardhan/Dropbox/Projects/macchi-trash
swift run
```

### Build app bundle

```bash
cd /Users/harshvardhan/Dropbox/Projects/macchi-trash
./build_app.sh
open /Users/harshvardhan/Dropbox/Projects/macchi-trash/MacchiTrash.app
```

### Restart running app

```bash
pkill -f MacchiTrash.app/Contents/MacOS/macchi-trash || true
open /Users/harshvardhan/Dropbox/Projects/macchi-trash/MacchiTrash.app
```

## Accessibility notes

- Bundle id in app plist: `com.harshvardhan.macchitrash`
- Permission reset command:

```bash
tccutil reset Accessibility com.harshvardhan.macchitrash
```

After reset, relaunch app and re-enable in:
- System Settings -> Privacy & Security -> Accessibility

## Suggested debugging plan for next LLM

1. Add temporary debug state in menu title:
   - `axTrusted`
   - `dockHit`
   - `trashFrameFound`
   - `fallbackEdgeActive`
   - `hoverActive`
2. Log both `mouseLocation` and resolved `hoverAnchor` every ~500ms while debugging.
3. Verify exact AX path first:
   - Ensure `hoverAnchorIfCursorIsOnTrash` fires while cursor is on visible Trash icon.
4. Only if exact path fails consistently, simplify:
   - Use manual calibration as primary behavior (explicitly user-calibrated) and treat AX as optional.
5. Keep strict product rule:
   - no flies when Dock/Trash not visible.

## Practical product direction

If AX continues to be inconsistent across machines:
- Keep a reliable user calibration mode as primary.
- Add explicit "Test marker" mode to show current anchor point.
- Make fallback behavior opt-in, not automatic.

This is likely the fastest path to stable user-visible behavior.
