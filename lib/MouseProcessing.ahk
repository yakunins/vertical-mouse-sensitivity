#Requires AutoHotkey v2.0

class MouseProcessing {
    __New(app) {
        this.app := app
        ; prevY is the only state we keep: the last KNOWN-REAL cursor Y, used to
        ; derive each move's delta. It is re-synced to reality on every event we
        ; don't act on, so any external cursor move is adopted, never fought.
        this.prevY := 0.0
        this.accumY := 0.0   ; sub-pixel accumulator for the EXTRA vertical offset
    }

    SyncCursorPos() {
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        this.prevY := NumGet(pt, 4, "Int") + 0.0
        this.accumY := 0.0
        this.app.log.Add("SYNC | prevY=" this.prevY " screenH=" A_ScreenHeight)
    }

    IsDragging() {
        return GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P")
    }

    ; Largest plausible single-event vertical move. A genuine hardware event never
    ; spans more than ~a screen; anything larger is an external teleport we never
    ; observed. Metric-free fallback keeps us safe even if the height momentarily
    ; reads 0 mid mode-switch (worst case: a few moves pass through unscaled —
    ; the cursor is never trapped).
    MaxDelta() {
        h := A_ScreenHeight
        return h > 0 ? h : 4320
    }

    LowLevelMouseProc(nCode, wParam, lParam) {
        Critical

        ; Only mouse-move (WM_MOUSEMOVE = 0x0200) is of interest.
        if !(nCode >= 0 && wParam = 0x0200)
            return MouseHookCallNext(nCode, wParam, lParam)

        curY := NumGet(lParam + 0, 4, "Int") + 0.0
        flags := NumGet(lParam + 0, 12, "UInt")
        injected := flags & 1

        settling := this.app.settleUntil && A_TickCount < this.app.settleUntil
        scaling := this.app.enabled && this.app.active && !this.app.tray.menuOpen && !injected && !settling && !(this.app.cfg.disableOnDrag && this.IsDragging())

        if !scaling {
            ; Disabled / excluded / menu open / dragging, or an injected event
            ; (our own SetCursorPos echo, or another app moving the cursor).
            ; Glue the baseline to the real position: when scaling resumes there
            ; is no jump, and any foreign move is simply adopted.
            this.app.log.Add("PASS | curY=" curY " inj=" injected " en=" this.app.enabled " act=" this.app.active, true)
            this.prevY := curY
            this.accumY := 0.0
            return MouseHookCallNext(nCode, wParam, lParam)
        }

        targetX := NumGet(lParam + 0, 0, "Int")
        targetY := curY
        prevY0 := this.prevY
        deltaY := targetY - this.prevY

        ; Teleport guard. We only react to genuine hardware movement. Anything
        ; that relocates the cursor without an event we could observe — display/
        ; resolution change, RDP/fast-user-switch, a warp not flagged injected,
        ; clip-rect changes — surfaces here as one implausibly large jump.
        ; Don't scale it: adopt it as the new baseline and let it pass through.
        if (Abs(deltaY) > this.MaxDelta()) {
            this.app.log.Add("TELEPORT | prevY=" prevY0 " targetY=" targetY " deltaY=" deltaY " max=" this.MaxDelta())
            this.prevY := targetY
            this.accumY := 0.0
            return MouseHookCallNext(nCode, wParam, lParam)
        }

        ; Add only the EXTRA vertical travel on top of what Windows already did:
        ;   extra = (multiplier - 1) * delta   (sub-pixel fractions accumulated)
        ; X is never part of this and is never written.
        this.accumY += deltaY * (this.app.cfg.yMultiplier - 1.0)
        extra := Integer(this.accumY)
        this.accumY -= extra

        if (extra = 0) {
            ; Nothing to add this event — let the native move flow through so apps
            ; still get a clean WM_MOUSEMOVE (hover, cursor shape, UWP/WinUI).
            this.prevY := targetY
            return MouseHookCallNext(nCode, wParam, lParam)
        }

        ; Reposition: X exactly as Windows intended, Y shifted by `extra`.
        finalY := targetY + extra
        DllCall("user32\SetCursorPos", "Int", targetX, "Int", finalY)

        ; SetCursorPos clamps to the desktop, so near an edge the cursor may land
        ; short of finalY. Read the real position back so prevY stays truthful and
        ; the next delta is correct — no screen-bounds math, nothing to desync.
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        this.prevY := NumGet(pt, 4, "Int") + 0.0
        this.app.log.Add("SCALE | prevY=" prevY0 " targetY=" targetY " deltaY=" deltaY " extra=" extra " finalY=" finalY " readback=" this.prevY " screenH=" A_ScreenHeight)
        return 1
    }
}
