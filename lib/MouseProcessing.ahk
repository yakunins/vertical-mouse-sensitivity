#Requires AutoHotkey v2.0

class MouseProcessing {
    __New(app) {
        this.app := app
        this.curX := 0.0
        this.curY := 0.0
        this.accumY := 0.0
    }

    SyncCursorPos() {
        pt := Buffer(8)
        DllCall("GetCursorPos", "Ptr", pt)
        this.curX := NumGet(pt, 0, "Int") + 0.0
        this.curY := NumGet(pt, 4, "Int") + 0.0
        this.accumY := 0.0
    }

    IsDragging() {
        return GetKeyState("LButton", "P") || GetKeyState("RButton", "P") || GetKeyState("MButton", "P")
    }

    LowLevelMouseProc(nCode, wParam, lParam) {
        Critical

        if (nCode >= 0 && wParam = 0x0200 && this.app.enabled && this.app.active && !this.app.tray.menuOpen) {
            flags := NumGet(lParam + 0, 12, "UInt")
            if !(flags & 1) {
                ; Allow native mouse movement during drag for drawing/painting apps
                if this.app.cfg.disableOnDrag && this.IsDragging() {
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
                this.accumY += deltaY * this.app.cfg.yMultiplier
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
