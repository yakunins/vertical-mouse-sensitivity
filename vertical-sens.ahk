#requires AutoHotkey v2.0
#singleinstance force

#include lib/Jsons.ahk
#include lib/MergeObjects.ahk
#include lib/UseBase64TrayIcon.ahk
#include lib/FileDebugLog.ahk
#include lib/MouseSpeed.ahk
#include lib/RawMouseInput.ahk
#include lib/MouseHook.ahk

class VerticalSens {
    static Version := "0.7"

    __New(cfg?) {
        defaultCfg := {
            disableForExe: [],
            disableInGames: false,
            gameExeList: [
                "cs2.exe", "csgo.exe",
                "dota2.exe",
                "TslGame.exe", "PUBG-Win64-Shipping.exe",
                "valorant.exe", "VALORANT-Win64-Shipping.exe",
                "LeagueClient.exe", "leagueoflegends.exe", "League of Legends.exe",
                "FortniteClient-Win64-Shipping.exe",
                "r5apex.exe",
                "GTA5.exe", "GTA6.exe", "FiveM.exe",
                "RustClient.exe", "Rust.exe",
                "eldenring.exe",
                "bg3.exe", "baldursgate3.exe",
                "RainbowSix.exe", "RainbowSixSiege.exe",
                "Overwatch.exe",
                "tf2.exe",
                "MarvelRivals.exe",
                "PathOfExile2.exe",
                "MonsterHunterWilds.exe",
                "aces.exe",
                "FC25.exe",
                "SlayTheSpire2.exe",
                "deadlock.exe",
                "Minecraft.Windows.exe", "Minecraft.exe", "javaw.exe",
                "RobloxPlayerBeta.exe",
                "Helldivers2.exe",
                "Cyberpunk2077.exe",
                "destiny2.exe",
                "RocketLeague.exe",
                "EscapeFromTarkov.exe",
                "starfield.exe",
                "callofduty.exe", "cod.exe",
                "WorldOfTanks.exe",
                "Diablo IV.exe",
                "Stardew Valley.exe"
            ],
            yMultiplier: 1.35,
            toggleShortcut: "#!v",
            trayIcon: "vertical",
            disableOnDrag: true,
            debug: false,
            debugLogMaxLines: 128,
            debugLogSampleRate: 10
        }

        userCfg := this.LoadConfig()
        this.cfg := userCfg ? MergeObjects(defaultCfg, userCfg) : defaultCfg
        this.enabled := true
        this.active := true
        this.hook := 0
        this.menuOpen := false
        this.lastToggleLabel := ""
        this.lastMultLabel := ""

        this.accumY := 0.0
        this.curX := 0.0
        this.curY := 0.0
        this.lastExe := ""
        this.rawToScreen := GetMouseSpeedFactor()
        this.BuildExclusionList()

        this.log := FileDebugLog(this.cfg.debug, A_ScriptDir "\debug.log", this.cfg.debugLogMaxLines, this.cfg.debugLogSampleRate)
        this.rawInput := RawMouseInput(ObjBindMethod(this, "OnMouseDelta"))
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
        ProcessSetPriority("High")
        this.log.Add("App started | priority=High | multiplier=" this.cfg.yMultiplier " rawToScreen=" Round(this.rawToScreen, 4) " debug=" this.cfg.debug)
        this.SetupTray()
        this.BindHotkey()
        this.SyncCursorPos()

        this.rawInput.Register()
        this.log.Add("Raw input registered")

        this.hook := MouseHookInstall(ObjBindMethod(this, "LowLevelMouseProc"))
        this.log.Add("Mouse hook installed")

        this.StartForegroundTracker()
        OnExit(ObjBindMethod(this, "OnAppExit"))
    }

    SetupTray() {
        this.UpdateTooltip()

        tray := A_TrayMenu
        tray.Delete()
        this.lastToggleLabel := this.ToggleMenuLabel()
        tray.Add(this.lastToggleLabel, ObjBindMethod(this, "Toggle"))
        tray.Add()
        this.lastMultLabel := this.MultiplierMenuLabel()
        tray.Add(this.lastMultLabel, ObjBindMethod(this, "ChangeMultiplier"))
        tray.Add()
        tray.Add("Exit", (*) => ExitApp())
        this.UpdateTrayIcon()
        OnMessage(0x0404, TrayClickHandler)
        TrayClickHandler(wP, lP, *) {
            if (lP = 0x0202 || lP = 0x0205) {  ; WM_LBUTTONUP or WM_RBUTTONUP
                app.menuOpen := true
                SetTimer(ShowTrayMenu, -1)
                return 1
            }
        }
        ShowTrayMenu() {
            A_TrayMenu.Show()  ; Blocks until menu closes
            app.menuOpen := false
            app.SyncCursorPos()
        }
    }

    MultiplierMenuLabel() {
        return "Y Multiplier: " Round(this.cfg.yMultiplier, 2) "x"
    }

    UpdateMultiplierMenu() {
        tray := A_TrayMenu
        newLabel := this.MultiplierMenuLabel()
        tray.Rename(this.lastMultLabel, newLabel)
        this.lastMultLabel := newLabel
    }

    ChangeMultiplier(*) {
        originalVal := this.cfg.yMultiplier
        activeVal := originalVal

        g := Gui("+AlwaysOnTop", "Y Multiplier")
        g.SetFont("s10")
        g.Add("Text", , "Y multiplier (0.1 – 20):")
        edit := g.Add("Edit", "w280 vMultVal", Round(originalVal, 2))
        btnTest := g.Add("Button", "w280 Disabled Default", "Test (Enter)")
        btnApply := g.Add("Button", "w280 Disabled", "Apply and save to config.json")
        btnCancel := g.Add("Button", "w280", "Cancel")

        validateInput := (*) => this.ValidateMultiplier(edit.Value)

        edit.OnEvent("Change", (*) => (
            btnTest.Enabled := validateInput() && Number(edit.Value) != activeVal,
            btnApply.Enabled := validateInput() && Number(edit.Value) != originalVal
        ))

        btnTest.OnEvent("Click", (*) => (
            activeVal := Number(edit.Value),
            this.cfg.yMultiplier := activeVal,
            this.UpdateMultiplierMenu(),
            btnTest.Enabled := false,
            btnApply.Enabled := activeVal != originalVal
        ))

        btnApply.OnEvent("Click", (*) => (
            this.cfg.yMultiplier := Number(edit.Value),
            this.UpdateMultiplierMenu(),
            this.SaveMultiplier(Number(edit.Value)),
            g.Destroy()
        ))

        cancelAction := (*) => (
            this.cfg.yMultiplier := originalVal,
            this.UpdateMultiplierMenu(),
            g.Destroy()
        )
        btnCancel.OnEvent("Click", cancelAction)
        g.OnEvent("Close", cancelAction)

        g.Show()
    }

    ValidateMultiplier(str) {
        val := 0
        try val := Number(str)
        return val >= 0.1 && val <= 20
    }

    SaveMultiplier(val) {
        configPath := A_ScriptDir "\config.json"
        try {
            jsonStr := FileRead(configPath, "UTF-8")
            jsonStr := RegExReplace(jsonStr, '("yMultiplier"\s*:\s*)[\d.]+', "${1}" Round(val, 2))
            FileDelete(configPath)
            FileAppend(jsonStr, configPath, "UTF-8")
        }
    }

    HotkeyDisplay() {
        return "Win+Alt+V"
    }

    UpdateTooltip() {
        A_IconTip := "Vertical Sensitivity v" . VerticalSens.Version
    }

    BindHotkey() {
        Hotkey(this.cfg.toggleShortcut, ObjBindMethod(this, "Toggle"))
    }

    BuildExclusionList() {
        this.excludedExes := Map()

        ; Add user-specified exe names
        if this.cfg.disableForExe is Array {
            for exe in this.cfg.disableForExe
                this.excludedExes[StrLower(exe)] := true
        }

        ; Add game exe list if enabled
        if this.cfg.disableInGames && this.cfg.gameExeList is Array {
            for exe in this.cfg.gameExeList
                this.excludedExes[StrLower(exe)] := true
        }
    }

    IsExcludedExe(exe) {
        return this.excludedExes.Has(StrLower(exe))
    }

    IsDragging() {
        return GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P")
    }

    SyncCursorPos() {
        ; Use GetCursorPos for physical screen coordinates (matches SetCursorPos)
        ; MouseGetPos defaults to window-relative coords which causes a jump
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        this.curX := NumGet(pt, 0, "Int") + 0.0
        this.curY := NumGet(pt, 4, "Int") + 0.0

        this.accumY := 0.0
    }

    ToggleMenuLabel() {
        action := this.enabled ? "Turn Off" : "Turn On"
        return action "`t" this.HotkeyDisplay()
    }

    UpdateTrayIcon() {
        icon := this.enabled ? "vertical" : "vertical_off"
        UseBase64TrayIcon(icon, this.cfg.debug)
    }

    UpdateToggleMenu() {
        tray := A_TrayMenu
        newLabel := this.ToggleMenuLabel()
        tray.Rename(this.lastToggleLabel, newLabel)
        this.lastToggleLabel := newLabel
    }

    Toggle(*) {
        this.enabled := !this.enabled
        if this.enabled
            this.SyncCursorPos()
        this.UpdateTrayIcon()
        this.UpdateToggleMenu()
        this.UpdateTooltip()
        this.log.Add("Toggled " (this.enabled ? "ON" : "OFF"))
    }

    OnMouseDelta(rawDX, rawDY) {
        ; Movement is now handled directly in the hook callback
        ; Raw input kept only for debug logging
        this.log.Add("Raw | rdx=" rawDX " rdy=" rawDY, true)
    }

    OnAppExit(*) {
        if this.hook
            MouseHookRemove(this.hook)
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
            wasActive := this.active
            this.active := !this.IsExcludedExe(exe)

            if wasActive && !this.active {
                this.log.Add("Foreground | " exe " (excluded, adjustment paused)")
            } else if !wasActive && this.active {
                this.SyncCursorPos()
                this.log.Add("Foreground | " exe " (adjustment resumed)")
            } else {
                this.log.Add("Foreground | " exe)
            }
        }
    }

    LowLevelMouseProc(nCode, wParam, lParam) {
        Critical

        if (nCode >= 0 && wParam = 0x0200 && this.enabled && this.active && !this.menuOpen) {
            flags := NumGet(lParam + 0, 12, "UInt")
            if !(flags & 1) {
                ; Allow native mouse movement during drag for drawing/painting apps
                if this.cfg.disableOnDrag && this.IsDragging() {
                    ; Sync tracked position so there's no jump when drag ends
                    this.curX := NumGet(lParam + 0, 0, "Int") + 0.0
                    this.curY := NumGet(lParam + 0, 4, "Int") + 0.0
                    this.accumY := 0.0
                    return MouseHookCallNext(nCode, wParam, lParam)
                }

                ; Get target position (where Windows wants to move cursor)
                targetX := NumGet(lParam + 0, 0, "Int")
                targetY := NumGet(lParam + 0, 4, "Int")

                ; Compute delta from our tracked position
                deltaY := targetY - this.curY

                ; Scale Y delta, accumulate fractions for sub-pixel precision
                this.accumY += deltaY * this.cfg.yMultiplier
                moveY := Integer(this.accumY)
                this.accumY -= moveY

                ; Update tracked position (X moves normally, Y scaled)
                this.curX := targetX + 0.0
                this.curY := this.curY + moveY

                ; Clamp to virtual screen bounds
                left := SysGet(76)
                top := SysGet(77)
                right := left + SysGet(78) - 1
                bottom := top + SysGet(79) - 1
                this.curX := Max(left + 0.0, Min(this.curX, right + 0.0))
                this.curY := Max(top + 0.0, Min(this.curY, bottom + 0.0))

                ; If scaled position matches target, no Y adjustment needed
                ; Let the message flow through so apps get WM_MOUSEMOVE (hover, cursor, etc.)
                finalX := Round(this.curX)
                finalY := Round(this.curY)
                if (finalX = targetX && finalY = targetY)
                    return MouseHookCallNext(nCode, wParam, lParam)

                ; Move cursor to scaled position, swallow original message
                ; SetCursorPos generates an echo WM_MOUSEMOVE which will pass through
                ; on next hook call (delta=0 → matches target → CallNextHookEx above)
                DllCall("user32\SetCursorPos", "Int", finalX, "Int", finalY)
                return 1
            }
            ; Injected by another app — sync our tracked position
            this.curX := NumGet(lParam + 0, 0, "Int") + 0.0
            this.curY := NumGet(lParam + 0, 4, "Int") + 0.0
        }

        return MouseHookCallNext(nCode, wParam, lParam)
    }
}

; Application entry point
global app := VerticalSens()
app.Run()