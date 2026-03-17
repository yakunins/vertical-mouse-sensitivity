#Requires AutoHotkey v2.0

; Windows pointer speed (SPI_GETMOUSESPEED 1-20) to raw-to-screen multiplier
; Speed 10 = 1.0 (1:1 raw count to screen pixel)
GetMouseSpeedFactor() {
    static factors := [
        0.03125, 0.0625, 0.125, 0.25, 0.375,
        0.5, 0.625, 0.75, 0.875, 1.0,
        1.25, 1.5, 1.75, 2.0, 2.25,
        2.5, 2.75, 3.0, 3.25, 3.5
    ]

    speed := 0
    DllCall("user32\SystemParametersInfo", "UInt", 0x0070, "UInt", 0, "Int*", &speed, "UInt", 0)
    if speed < 1 || speed > 20
        speed := 10
    return factors[speed]
}
