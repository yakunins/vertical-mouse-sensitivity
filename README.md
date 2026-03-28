# Vertical Mouse Sensitivity

Adjust vertical (Y-axis) mouse sensitivity independently from horizontal on Windows.  
When enabled, vertical mouse movement is scaled by `yMultiplier`. Horizontal movement is unchanged.  
Uses raw input (WM_INPUT) for sub-pixel precision at slow speeds.  
Built with AutoHotkey v2.  

## Install

1. Download the latest [`vertical-sens-v*.zip`](https://github.com/yakunins/vertical-mouse-sensitivity/releases/latest) from Releases
2. Extract into a permanent folder (e.g. `C:\vertical-sens\`)
3. Run `install.cmd` — creates a startup shortcut so the app launches on boot

## Usage

- **Win+Alt+V** toggles adjustment on/off
- **System tray icon** shows current state; click for menu
- **Y Multiplier** can be changed via tray menu with test/apply/save

## Configure

Edit `config.json` and restart the app, or change Y Multiplier via tray menu.

| Setting          | Default | Description                                                     |
| ---------------- | ------- | --------------------------------------------------------------- |
| `yMultiplier`    | `1.35`  | Vertical sensitivity multiplier (e.g., `2` = 2x vertical speed) |
| `toggleShortcut` | `"#!v"` | AHK hotkey to toggle on/off (`#!v` = Win+Alt+V)                 |
| `disableForExe`  | `[]`    | Exe names to pause adjustment for (e.g., `["photoshop.exe"]`)   |
| `disableInGames` | `false` | Auto-disable for common games (CS2, Valorant, Fortnite, etc.)   |
| `disableOnDrag`  | `true`  | Disable adjustment while a mouse button is held (fixes drawing in Snipping Tool, Paint, etc.) |

## License
MIT

Enjoy!  
A donut, [maybe](https://www.paypal.com/donate/?business=KXM47EKBXFV4S&no_recurring=0&item_name=funding+of+github.com%2Fyakunins&currency_code=USD)? 🍩
