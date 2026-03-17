#Requires AutoHotkey v2.0

; Install/remove WH_MOUSE_LL hook with callback management
MouseHookInstall(callback) {
    hookCb := CallbackCreate(callback, , 3)

    ; WH_MOUSE_LL = 14
    hHook := DllCall("SetWindowsHookEx"
        , "Int", 14
        , "Ptr", hookCb
        , "Ptr", 0
        , "UInt", 0
        , "Ptr")

    if !hHook {
        CallbackFree(hookCb)
        throw Error("Failed to install mouse hook")
    }

    return { hHook: hHook, hookCb: hookCb }
}

MouseHookRemove(hook) {
    if hook.hHook {
        DllCall("UnhookWindowsHookEx", "Ptr", hook.hHook)
        hook.hHook := 0
    }
    if hook.hookCb {
        CallbackFree(hook.hookCb)
        hook.hookCb := 0
    }
}

MouseHookCallNext(nCode, wParam, lParam) {
    return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UPtr", wParam, "Ptr", lParam, "Ptr")
}
