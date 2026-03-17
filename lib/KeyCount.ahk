#Requires AutoHotkey v2.0

global KeyCount := 0 
keys := [
	"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
	"1","2","3","4","5","6","7","8","9","0",
	"F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
	"Space","Enter","Tab","LShift","RShift","LCtrl","RCtrl","LAlt","RAlt", "Backspace","Delete",
	"Up","Down","Left","Right",
	"Home","End","PgUp","PgDn",
	"Insert","PrintScreen","ScrollLock","Pause","CapsLock",
	"Numpad0","Numpad1","Numpad2","Numpad3","Numpad4","Numpad5","Numpad6","Numpad7","Numpad8","Numpad9",
	"NumpadAdd","NumpadSub","NumpadMult","NumpadDiv","NumpadEnter"
]

for key in keys {
	Hotkey key, KeyDown
	Hotkey key " up", KeyUp 
}

KeyDown(key) { global KeyCount KeyCount++ }

KeyUp(key) { global KeyCount KeyCount-- if (KeyCount < 0) KeyCount := 0 }

