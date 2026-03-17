#requires AutoHotkey v2.0
#singleinstance force

#include lib/Jsons.ahk
#include lib/MergeObjects.ahk
#include lib/UseBase64TrayIcon.ahk

class DebugLog {
    __New(enabled, filePath, maxLines := 128, sampleRate := 10) {
        this.enabled := enabled
        this.filePath := filePath
        this.maxLines := maxLines
        this.sampleRate := sampleRate
        this.buffer := []
        this.writeCount := 0
        this.sampleCount := 0
    }

    Add(message, sampled := false) {
        if !this.enabled
            return

        if sampled {
            this.sampleCount++
            if Mod(this.sampleCount, this.sampleRate) != 0
                return
        }

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        this.buffer.Push("[" timestamp "] " message)

        while this.buffer.Length > this.maxLines
            this.buffer.RemoveAt(1)

        this.writeCount++
        if this.writeCount >= 50
            this.Flush()
    }

    Flush() {
        if !this.enabled || !this.buffer.Length
            return
        text := ""
        for line in this.buffer
            text .= line "`n"
        try FileOpen(this.filePath, "w", "UTF-8").Write(text)
        this.writeCount := 0
    }
}

class VerticalSens {
    static Version := "0.1"

    __New(cfg?) {
        defaultCfg := {
            excludeApps: [],
            multiplier: 1.35,
            toggleShortcut: "#!v",
            trayIcon: "vertical",
            debug: false,
            logMaxLines: 128,
            logSampleRate: 10
        }

        userCfg := this.LoadConfig()
        this.cfg := userCfg ? MergeObjects(defaultCfg, userCfg) : defaultCfg
        this.enabled := true
        this.hHook := 0
        this.lastY := 0
        this.injecting := false
        this.accumY := 0.0
        this.lastExe := ""

        this.log := DebugLog(this.cfg.debug, A_ScriptDir "\debug.log", this.cfg.logMaxLines, this.cfg.logSampleRate)
    }

    LoadConfig() {
        configPath := A_ScriptDir "\config.json"
        if !FileExist(configPath)
            return false
        try {
            jsonStr := FileRead(configPath, "UTF-8")
            return MapToObj(Jsons.Load(&jsonStr))
        } catch {
            return false
        }
    }

    Run() {
        this.log.Add("App started | multiplier=" this.cfg.multiplier " debug=" this.cfg.debug)
        this.SetupTray()
        this.BindHotkey()
        this.InstallHook()
    }

    SetupTray() {
        UseBase64TrayIcon(this.cfg.trayIcon, this.cfg.debug)
        this.UpdateTooltip()

        tray := A_TrayMenu
        tray.Delete()
        tray.Add("Toggle ON/OFF`t" this.HotkeyDisplay(), ObjBindMethod(this, "Toggle"))
        tray.Add()
        tray.Add("Multiplier: " this.cfg.multiplier "x", (*) => 0)
        tray.Disable("Multiplier: " this.cfg.multiplier "x")
        tray.Add()
        tray.Add("Exit", (*) => ExitApp())
        tray.Default := "Toggle ON/OFF`t" this.HotkeyDisplay()
    }

    HotkeyDisplay() {
        return "Win+Alt+V"
    }

    UpdateTooltip() {
        state := this.enabled ? "ON" : "OFF"
        A_IconTip := "Vertical Sensitivity v" . VerticalSens.Version . " [" . state . "]"
    }

    BindHotkey() {
        Hotkey(this.cfg.toggleShortcut, ObjBindMethod(this, "Toggle"))
    }

    Toggle(*) {
        this.enabled := !this.enabled
        this.accumY := 0.0
        this.UpdateTooltip()
        this.log.Add("Toggled " (this.enabled ? "ON" : "OFF"))
    }

    InstallHook() {
        this.hookCallback := CallbackCreate(ObjBindMethod(this, "LowLevelMouseProc"), , 3)

        ; WH_MOUSE_LL = 14
        this.hHook := DllCall("SetWindowsHookEx"
            , "Int", 14
            , "Ptr", this.hookCallback
            , "Ptr", 0
            , "UInt", 0
            , "Ptr")

        if !this.hHook {
            this.log.Add("Hook install failed")
            this.log.Flush()
            throw Error("Failed to install mouse hook")
        }

        this.log.Add("Mouse hook installed")
        this.StartForegroundTracker()
        OnExit(ObjBindMethod(this, "OnAppExit"))
    }

    OnAppExit(*) {
        this.RemoveHook()
        this.log.Add("App exited")
        this.log.Flush()
    }

    StartForegroundTracker() {
        SetTimer(ObjBindMethod(this, "CheckForegroundApp"), 500)
    }

    CheckForegroundApp() {
        try exe := WinGetProcessName("A")
        catch
            return
        if (exe != this.lastExe) {
            this.lastExe := exe
            this.log.Add("Foreground | " exe)
        }
    }

    RemoveHook() {
        if this.hHook {
            DllCall("UnhookWindowsHookEx", "Ptr", this.hHook)
            this.hHook := 0
        }
        if this.hookCallback {
            CallbackFree(this.hookCallback)
            this.hookCallback := 0
        }
    }

    LowLevelMouseProc(nCode, wParam, lParam) {
        Critical

        ; WM_MOUSEMOVE = 0x0200
        if (nCode >= 0 && wParam = 0x0200 && this.enabled && !this.injecting) {
            flags := NumGet(lParam + 0, 12, "UInt")

            ; Skip events generated by our SetCursorPos
            if !(flags & 1) {
                currentX := NumGet(lParam + 0, 0, "Int")
                currentY := NumGet(lParam + 0, 4, "Int")

                if this.lastY {
                    deltaY := currentY - this.lastY
                    if deltaY != 0 {
                        ; Accumulate fractional to prevent rounding loss
                        this.accumY += deltaY * (this.cfg.multiplier - 1)
                        inject := Integer(this.accumY)

                        if inject != 0 {
                            this.accumY -= inject
                            newY := currentY + inject

                            ; Block original event and set cursor to adjusted position
                            this.injecting := true
                            DllCall("user32\SetCursorPos", "Int", currentX, "Int", newY)
                            this.injecting := false

                            this.lastY := newY
                            this.log.Add("Adjusted | dy=" deltaY " inject=" inject " y=" currentY "->" newY, true)
                            return 1
                        }
                    }
                }

                this.lastY := currentY
            }
        }

        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }
}

; Application entry point
global app := VerticalSens()
app.Run()
