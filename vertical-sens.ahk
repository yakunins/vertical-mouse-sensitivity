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
    static Version := "0.3"

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
        this.active := true
        this.hook := 0
        this.injecting := false
        this.accumX := 0.0
        this.accumY := 0.0
        this.curX := 0.0
        this.curY := 0.0
        this.lastExe := ""
        this.rawToScreen := GetMouseSpeedFactor()
        this.BuildExclusionList()

        this.log := FileDebugLog(this.cfg.debug, A_ScriptDir "\debug.log", this.cfg.logMaxLines, this.cfg.logSampleRate)
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
        this.log.Add("App started | multiplier=" this.cfg.multiplier " rawToScreen=" Round(this.rawToScreen, 4) " debug=" this.cfg.debug)
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
        UseBase64TrayIcon(this.cfg.trayIcon, this.cfg.debug)
        this.UpdateTooltip()

        tray := A_TrayMenu
        tray.Delete()
        tray.Add("Toggle ON/OFF`t" this.HotkeyDisplay(), ObjBindMethod(this, "Toggle"))
        tray.Add()
        mult := Round(this.cfg.multiplier, 2)
        tray.Add("Multiplier: " mult "x", (*) => 0)
        tray.Disable("Multiplier: " mult "x")
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

    SyncCursorPos() {
        ; Use GetCursorPos for physical screen coordinates (matches SetCursorPos)
        ; MouseGetPos defaults to window-relative coords which causes a jump
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        this.curX := NumGet(pt, 0, "Int") + 0.0
        this.curY := NumGet(pt, 4, "Int") + 0.0
        this.accumX := 0.0
        this.accumY := 0.0
    }

    Toggle(*) {
        this.enabled := !this.enabled
        if this.enabled
            this.SyncCursorPos()
        this.UpdateTooltip()
        this.log.Add("Toggled " (this.enabled ? "ON" : "OFF"))
    }

    OnMouseDelta(rawDX, rawDY) {
        if !this.enabled || !this.active
            return

        ; Convert raw counts to screen pixels: X at 1:1, Y scaled by multiplier
        this.accumX += rawDX * this.rawToScreen
        this.accumY += rawDY * this.rawToScreen * this.cfg.multiplier

        ; Extract whole pixels to emit
        moveX := Integer(this.accumX)
        moveY := Integer(this.accumY)

        if moveX = 0 && moveY = 0
            return

        this.accumX -= moveX
        this.accumY -= moveY
        this.curX += moveX
        this.curY += moveY

        ; Clamp to virtual screen bounds
        left := SysGet(76)
        top := SysGet(77)
        right := left + SysGet(78) - 1
        bottom := top + SysGet(79) - 1
        this.curX := Max(left + 0.0, Min(this.curX, right + 0.0))
        this.curY := Max(top + 0.0, Min(this.curY, bottom + 0.0))

        this.injecting := true
        DllCall("user32\SetCursorPos", "Int", Round(this.curX), "Int", Round(this.curY))
        this.injecting := false

        this.log.Add("Raw | rdx=" rawDX " rdy=" rawDY " mx=" moveX " my=" moveY, true)
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

        ; Block real WM_MOUSEMOVE when enabled and active (handled via raw input)
        if (nCode >= 0 && wParam = 0x0200 && this.enabled && this.active && !this.injecting) {
            flags := NumGet(lParam + 0, 12, "UInt")
            if !(flags & 1)
                return 1
            ; Injected by another app — sync our tracked position
            if !this.injecting {
                this.curX := NumGet(lParam + 0, 0, "Int") + 0.0
                this.curY := NumGet(lParam + 0, 4, "Int") + 0.0
            }
        }

        return MouseHookCallNext(nCode, wParam, lParam)
    }
}

; Application entry point
global app := VerticalSens()
app.Run()
