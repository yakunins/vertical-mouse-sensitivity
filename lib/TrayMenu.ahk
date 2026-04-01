#Requires AutoHotkey v2.0

class TrayMenu {
    __New(app, labels) {
        this.app := app
        this.labels := labels
        this.lastToggleLabel := ""
        this.lastMultLabel := ""
        this.menuOpen := false
    }

    Setup() {
        this.UpdateTooltip()

        tray := A_TrayMenu
        tray.Delete()
        this.lastMultLabel := this.app.mult.MenuLabel()
        tray.Add(this.lastMultLabel, ObjBindMethod(this.app.mult, "Show"))
        tray.Add() ; divider
        this.lastToggleLabel := this.ToggleMenuLabel()
        tray.Add(this.lastToggleLabel, ObjBindMethod(this.app, "Toggle"))
        tray.Add() ; divider
        tray.Add(this.labels.exit, (*) => ExitApp())
        this.UpdateIcon()

        trayMenu := this
        OnMessage(0x0404, TrayClickHandler)
        TrayClickHandler(wP, lP, *) {
            if (lP = 0x0202 || lP = 0x0205) {  ; WM_LBUTTONUP or WM_RBUTTONUP
                trayMenu.menuOpen := true
                SetTimer(ShowTrayMenu, -1)
                return 1
            }
        }
        ShowTrayMenu() {
            A_TrayMenu.Show()  ; Blocks until menu closes
            trayMenu.menuOpen := false
            trayMenu.app.mouseProcessing.SyncCursorPos()
        }
    }

    HotkeyDisplay() {
        return this.labels.hotkeyDisplay
    }

    UpdateTooltip() {
        A_IconTip := this.labels.tooltipPrefix . VerticalSens.Version . "`n×" . Round(this.app.cfg.yMultiplier, 2)
    }

    ToggleMenuLabel() {
        action := this.app.enabled ? this.labels.turnOff : this.labels.turnOn
        return action "`t" this.HotkeyDisplay()
    }

    UpdateToggle() {
        tray := A_TrayMenu
        newLabel := this.ToggleMenuLabel()
        tray.Rename(this.lastToggleLabel, newLabel)
        this.lastToggleLabel := newLabel
    }

    UpdateIcon() {
        icon := this.app.enabled ? "vertical" : "vertical_off"
        UseBase64TrayIcon(icon, this.app.cfg.debug)
    }
}