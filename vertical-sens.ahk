#requires AutoHotkey v2.0
#singleinstance force

; Replace the base AutoHotkey manifest with a Per-Monitor-V2 one at compile time.
; The OS reads this before AHK starts, making the process default PMv2 — the only
; awareness level that reaches the WH_MOUSE_LL hook callback, where Windows runs
; under the PROCESS default (SetProcess/ThreadDpiAwarenessContext can't change it
; from script). The .manifest extension makes Ahk2Exe use resource type 24
; (RT_MANIFEST); name 1 is the process manifest, replacing AHK's default.
;@Ahk2Exe-AddResource vertical-sens.manifest, 1

; Per-Monitor-V2 DPI awareness. Without it a resolution/scaling change
; virtualizes some pointer APIs but not others: A_ScreenHeight and GetCursorPos
; report DPI-scaled coordinates (e.g. 1620 on a 2160 panel) while the
; WH_MOUSE_LL hook keeps physical pixels. That coordinate-space mismatch makes
; every Y delta bogus and drifts the cursor to the top of the screen.
;
; SetProcessDpiAwarenessContext is refused once the process window exists (AHK
; locks it during its own startup, before this line runs), so we set awareness
; at the THREAD level instead — that is not locked and is honored live. AHK is
; single-OS-threaded, so this one call covers the hook callback, the timers and
; every GetCursorPos / SetCursorPos / A_ScreenHeight read. It must run before
; the hook is installed so the LL-hook pt is delivered in physical pixels.
try {
    if !DllCall("User32\SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")  ; PER_MONITOR_AWARE_V2 (Win10 1703+)
        DllCall("User32\SetThreadDpiAwarenessContext", "Ptr", -3, "Ptr")  ; PER_MONITOR_AWARE (1607+ fallback)
}

#include lib/Jsons.ahk
#include lib/MergeObjects.ahk

#include lib/UseBase64TrayIcon.ahk   ; embed tray icons as base64 strings
#include lib/FileDebugLog.ahk        ; rotating debug log with sampling, writes to debug.log when debug=true
#include lib/MouseSpeed.ahk          ; read Windows pointer speed factor (from Control Panel > Mouse > Pointer Speed)
#include lib/RawMouseInput.ahk       ; register for WM_INPUT raw mouse events, bypassing Windows pointer acceleration
#include lib/MouseHook.ahk           ; install/remove WH_MOUSE_LL hook
#include lib/TrayMenu.ahk            ; system tray menu and icon management
#include lib/MultiplierGui.ahk       ; Y multiplier dialog box GUI with test/apply/save buttons
#include lib/MouseProcessing.ahk     ; low-level mouse hook callback and cursor state

class VerticalSens {
    static Version := "0.94"

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
            yMultiplier: 1.40,
            toggleShortcut: "#!v",
            trayIcon: "vertical",
            disableOnDrag: false,
            foregroundCheckInterval: 200,
            debug: false,
            debugLogMaxLines: 128,
            debugLogSampleRate: 10
        }

        userCfg := this.LoadConfig()
        this.cfg := userCfg ? MergeObjects(defaultCfg, userCfg) : defaultCfg
        this.enabled := true
        this.active := true
        this.hook := 0
        this.settleUntil := 0   ; A_TickCount until which scaling is suspended after a display change

        this.lastExe := ""
        this.rawToScreen := GetMouseSpeedFactor()
        this.BuildExclusionList()

        this.log := FileDebugLog(this.cfg.debug, A_ScriptDir "\debug.log", this.cfg.debugLogMaxLines, this.cfg.debugLogSampleRate)
        this.mouseProcessing := MouseProcessing(this)

        trayLabels := {
            exit: "Exit",
            hotkeyDisplay: "Win+Alt+V",
            tooltipPrefix: "Vertical Mouse Sensitivity v",
            turnOff: "Turn Off",
            turnOn: "Turn On"
        }
        guiLabels := {
            menuPrefix: "Y Multiplier: ",
            menuSuffix: "x",
            windowTitle: "Vertical Mouse Sensitivity",
            inputLabel: "Y multiplier (0.1 – 20):",
            btnTest: "Test (Enter)",
            btnApply: "Apply and Save",
            btnCancel: "Cancel (Esc)"
        }

        this.tray := TrayMenu(this, trayLabels)
        this.mult := MultiplierGui(this, this.tray, guiLabels)
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
        this.tray.Setup()
        this.BindHotkey()
        this.mouseProcessing.SyncCursorPos()

        this.rawInput.Register()
        this.log.Add("Raw input registered")

        this.hook := MouseHookInstall(ObjBindMethod(this.mouseProcessing, "LowLevelMouseProc"))
        this.log.Add("Mouse hook installed")

        this.StartForegroundTracker()

        ; Resolution/display changes invalidate the tracked cursor position and
        ; can momentarily report bogus virtual-screen metrics. Re-sync so scaling
        ; restarts from the real cursor instead of fighting it into a corner.
        OnMessage(0x007E, ObjBindMethod(this, "OnDisplayChange"))  ; WM_DISPLAYCHANGE

        OnExit(ObjBindMethod(this, "OnAppExit"))
    }

    OnDisplayChange(wParam, lParam, msg, hwnd) {
        ; A resolution/scaling switch is not instantaneous — for up to ~1.5s the
        ; coordinate space keeps shifting, surfacing as a cascade of large bogus
        ; deltas. Suspend scaling for that window so native movement passes through
        ; untouched, then re-sync from the settled, real cursor position.
        this.settleUntil := A_TickCount + 1500
        this.mouseProcessing.SyncCursorPos()
        this.log.Add("Display changed | scaling suspended " (this.settleUntil - A_TickCount) "ms | screenH=" A_ScreenHeight)
        SetTimer(ObjBindMethod(this, "EndSettle"), -1500)
    }

    EndSettle() {
        this.settleUntil := 0
        this.mouseProcessing.SyncCursorPos()
        this.log.Add("Settle ended | cursor re-synced | screenH=" A_ScreenHeight)
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

    Toggle(*) {
        ; Sync BEFORE flipping the flag on the off→on transition — otherwise
        ; the LL hook can fire in the race window and scale against a stale curY.
        if !this.enabled
            this.mouseProcessing.SyncCursorPos()
        this.enabled := !this.enabled
        this.tray.UpdateIcon()
        this.tray.UpdateToggle()
        this.tray.UpdateTooltip()
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
        SetTimer(ObjBindMethod(this, "CheckForegroundApp"), this.cfg.foregroundCheckInterval)
    }

    CheckForegroundApp() {
        try exe := WinGetProcessName("A")
        catch
            return
        if (exe != this.lastExe) {
            this.lastExe := exe
            wasActive := this.active
            newActive := !this.IsExcludedExe(exe)

            if wasActive && !newActive {
                this.active := newActive
                this.log.Add("Foreground | " exe " (excluded, adjustment paused)")
            } else if !wasActive && newActive {
                ; Sync BEFORE flipping the flag — otherwise the LL hook can fire
                ; in the race window and scale against a stale curY (jump bug).
                this.mouseProcessing.SyncCursorPos()
                this.active := newActive
                this.log.Add("Foreground | " exe " (adjustment resumed)")
            } else {
                this.active := newActive
                this.log.Add("Foreground | " exe)
            }
        }
    }

}

; Application entry point
global app := VerticalSens()
app.Run()