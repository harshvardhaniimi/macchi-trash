# Macchi Trash

Macchi Trash is a tiny macOS menu-bar app that shows animated flies near the Trash icon in the Dock whenever `~/.Trash` contains files.

## Current project state

- The app builds and launches.
- Trash hover detection is currently inconsistent on some setups (especially with Dock auto-hide).
- For engineering handoff and debugging context, see `docs/HANDOFF.md`.

## What it does

- Watches your local Trash folder (`~/.Trash`) and surfaces status in the menu
- Attempts to show a transparent fly overlay when cursor hovers Trash in Dock
- Supports manual calibration and Accessibility-assisted anchoring attempts
- Adds a menu-bar icon with a live status and a Quit action

## Requirements

- macOS 13+
- Xcode Command Line Tools (for `swift build` / `swift run`)

## Run

```bash
cd /Users/harshvardhan/Dropbox/Projects/macchi-trash
swift run
```

## Build .app bundle

```bash
cd /Users/harshvardhan/Dropbox/Projects/macchi-trash
./build_app.sh
open /Users/harshvardhan/Dropbox/Projects/macchi-trash/MacchiTrash.app
```

## Calibrate Trash position

If flies are not exactly over the Trash icon:

1. Open the menu bar icon for Macchi Trash.
2. Click `Calibrate Trash Position (5s)`.
3. Move the cursor over the Trash icon and keep it there for 5 seconds.

The app saves this anchor and reuses it after restart. Use `Clear Calibration` to reset.

## Notes

- Hover detection currently has known reliability issues on some systems (especially with Dock auto-hide).
- Overlay position uses a mix of Accessibility and Dock geometry fallbacks.
- The app runs as an accessory app (no Dock icon), controlled from the menu bar.
