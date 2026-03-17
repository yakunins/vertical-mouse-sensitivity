# Vertical Mouse Sensitivity

Adjust vertical (Y-axis) mouse sensitivity independently from horizontal on Windows. Built with AutoHotkey v2.

Useful when your mouse feels too slow vertically but horizontal is fine, or you want different vertical speed without changing your DPI.

## Install

1. Download [`vertical-sens.exe`](https://github.com/yakunins/y-mouse-sens/releases/latest/download/vertical-sens.exe), [`config.json`](https://github.com/yakunins/y-mouse-sens/releases/latest/download/config.json), and [`install.cmd`](https://github.com/yakunins/y-mouse-sens/releases/latest/download/install.cmd) into a separate folder (e.g. `C:\vertical-sens\`)
2. Run `install.cmd` — creates a startup shortcut so the app launches on boot

## Configure

Edit `config.json` and restart the app.

| Setting          | Default | Description                                                     |
| ---------------- | ------- | --------------------------------------------------------------- |
| `multiplier`     | `1.35`  | Vertical sensitivity multiplier (e.g., `2` = 2x vertical speed) |
| `toggleShortcut` | `"#!v"` | AHK hotkey to toggle on/off (`#!v` = Win+Alt+V)                 |
| `disableForExe`  | `[]`    | Exe names to pause adjustment for (e.g., `["photoshop.exe"]`)   |
| `disableInGames` | `false` | Auto-disable for common games (CS2, Valorant, Fortnite, etc.)   |
| `disableOnDrag`  | `true`  | Disable adjustment while a mouse button is held (fixes drawing in Snipping Tool, Paint, etc.) |

## Usage

- **Win+Alt+V** toggles adjustment on/off
- **System tray icon** shows current state; right-click for menu
- **Double-click tray icon** to toggle

When enabled, vertical mouse movement is scaled by `multiplier`. Horizontal movement is unchanged.

Uses raw input (WM_INPUT) for sub-pixel precision at slow speeds.

## Uninstall

Download [`uninstall.cmd`](https://github.com/yakunins/y-mouse-sens/releases/latest/download/uninstall.cmd) into the app folder and run it to remove the startup shortcut. Delete the folder.

## License

MIT
