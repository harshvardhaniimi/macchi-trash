# Macchi Trash

<img width="961" height="670" alt="image" src="https://github.com/user-attachments/assets/2adcf16e-c492-4082-9c1c-38b3f9491260" />


A tiny macOS menu-bar app that shows animated flies buzzing around your Trash icon when it has items. Because trash attracts *macchi*.

> **macchi** (मक्खी) is Hindi for "fly" — the pesky kind that won't leave your trash alone.

**[Website](https://harshvardhaniimi.github.io/macchi-trash/)** · **[Download](https://github.com/harshvardhaniimi/macchi-trash/releases/latest/download/MacchiTrash.zip)**

## How it works

1. Trash has items → 2. Hover cursor over Trash in Dock → 3. Flies appear

The app watches `~/.Trash` and uses macOS Accessibility APIs to detect when your cursor is over the Trash icon. When both conditions are met, animated flies appear over the icon.

## Install

Download [MacchiTrash.zip](https://github.com/harshvardhaniimi/macchi-trash/releases/latest/download/MacchiTrash.zip), extract, move to Applications, and right-click → Open the first time. Grant Accessibility permission when prompted.

## Build from source

Requires Xcode Command Line Tools.

```bash
git clone https://github.com/harshvardhaniimi/macchi-trash.git
cd macchi-trash
./build_app.sh
open MacchiTrash.app
```

## Calibrate Trash position

If flies don't appear in the right spot:

1. Click the menu bar icon (🗑️).
2. Click **Calibrate Trash Position (5s)**.
3. Move the cursor over the Trash icon and hold for 5 seconds.

The calibrated position persists across restarts. Use **Clear Calibration** to reset.

## Permissions

- **Accessibility** — required to detect the Trash icon position in the Dock. The app only reads Dock element positions; it does not monitor keystrokes or read window contents.

## Requirements

- macOS 13+
- Apple Silicon or Intel

## License

MIT

---

Built with [Claude Code](https://claude.ai/code).
