#Requires AutoHotkey v2.0

class RawMouseInput {
    __New(callback) {
        this.callback := callback
        this._registered := false
    }

    Register() {
        if this._registered
            return

        ; RAWINPUTDEVICE: usUsagePage(2) + usUsage(2) + dwFlags(4) + hwndTarget(Ptr)
        ridSize := 8 + A_PtrSize
        rid := Buffer(ridSize, 0)
        NumPut("UShort", 1, rid, 0)          ; HID_USAGE_PAGE_GENERIC
        NumPut("UShort", 2, rid, 2)          ; HID_USAGE_GENERIC_MOUSE
        NumPut("UInt", 0x00000100, rid, 4)   ; RIDEV_INPUTSINK
        NumPut("Ptr", A_ScriptHwnd, rid, 8)  ; hwndTarget

        if !DllCall("RegisterRawInputDevices", "Ptr", rid, "UInt", 1, "UInt", ridSize)
            throw Error("Failed to register raw input device")

        OnMessage(0x00FF, ObjBindMethod(this, "_OnWmInput"))
        this._registered := true
    }

    _OnWmInput(wParam, lParam, msg, hwnd) {
        static headerSize := A_PtrSize = 8 ? 24 : 16

        ; Get raw input data
        pcbSize := 0
        DllCall("GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", 0, "UInt*", &pcbSize, "UInt", headerSize)

        buf := Buffer(pcbSize)
        DllCall("GetRawInputData", "Ptr", lParam, "UInt", 0x10000003, "Ptr", buf, "UInt*", &pcbSize, "UInt", headerSize)

        ; RIM_TYPEMOUSE = 0
        if NumGet(buf, 0, "UInt") != 0
            return

        ; RAWMOUSE.usFlags — skip absolute positioning devices
        if NumGet(buf, headerSize, "UShort") & 1
            return

        ; RAWMOUSE.lLastX at headerSize+12, lLastY at headerSize+16
        rawDX := NumGet(buf, headerSize + 12, "Int")
        rawDY := NumGet(buf, headerSize + 16, "Int")

        if rawDX = 0 && rawDY = 0
            return

        this.callback.Call(rawDX, rawDY)
    }
}
