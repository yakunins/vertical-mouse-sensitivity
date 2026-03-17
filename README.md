# Vertical Mouse Sensitivity

Adjust vertical (Y-axis) mouse sensitivity independently from horizontal on Windows. Built with AutoHotkey v2.

Useful when your mouse feels too slow vertically but horizontal is fine, or you want different vertical speed without changing your DPI.

## Install

1. Install [AutoHotkey v2](https://www.autohotkey.com/)
2. Clone or download this repo
3. Run `vertical-sens.ahk`

The app runs in the system tray.

To start on boot, run `install.cmd` (creates a startup shortcut). Requires compiling first via `compile.cmd`.

## Configure

Edit `config.json` and restart the app.

| Setting | Default | Description |
|---------|---------|-------------|
| `multiplier` | `1.35` | Vertical sensitivity multiplier (e.g., `2` = 2x vertical speed) |
| `toggleShortcut` | `"#!v"` | AHK hotkey to toggle on/off (`#!v` = Win+Alt+V) |
| `excludeApps` | `[]` | Process names to skip (not yet implemented) |
| `trayIcon` | `"vertical"` | Tray icon theme (`vertical`, `bell`, `eye`, `shield`, `transparent`) |
| `debug` | `false` | Write `debug.log` with rolling event log |
| `logMaxLines` | `128` | Max lines kept in debug log |
| `logSampleRate` | `10` | Log every Nth mouse adjustment (reduces noise) |

## Usage

- **Win+Alt+V** toggles adjustment on/off
- **System tray icon** shows current state; right-click for menu
- **Double-click tray icon** to toggle

When enabled, vertical mouse movement is scaled by `multiplier`. Horizontal movement is unchanged.

Uses raw input (WM_INPUT) for sub-pixel precision at slow speeds.

## Uninstall

Run `uninstall.cmd` to remove the startup shortcut. Delete the folder.

## Requirements

- Windows 10/11
- AutoHotkey v2.0+

## License

MIT
