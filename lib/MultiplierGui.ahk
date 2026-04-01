#Requires AutoHotkey v2.0

class MultiplierGui {
    __New(app, tray) {
        this.app := app
        this.tray := tray
    }

    MenuLabel() {
        return "Y Multiplier: " Round(this.app.cfg.yMultiplier, 2) "x"
    }

    UpdateMenu() {
        tray := A_TrayMenu
        newLabel := this.MenuLabel()
        tray.Rename(this.tray.lastMultLabel, newLabel)
        this.tray.lastMultLabel := newLabel
    }

    Show(*) {
        originalVal := this.app.cfg.yMultiplier
        activeVal := originalVal

        g := Gui("+AlwaysOnTop", "Y Multiplier")
        g.SetFont("s10")
        g.Add("Text", , "Y multiplier (0.1 – 20):")
        edit := g.Add("Edit", "w280 vMultVal", Round(originalVal, 2))
        btnTest := g.Add("Button", "w280 Disabled Default", "Test (Enter)")
        btnApply := g.Add("Button", "w280 Disabled", "Apply and save to config.json")
        btnCancel := g.Add("Button", "w280", "Cancel")

        validateInput := (*) => this.Validate(edit.Value)

        edit.OnEvent("Change", (*) => (
            btnTest.Enabled := validateInput() && Number(edit.Value) != activeVal,
            btnApply.Enabled := validateInput() && Number(edit.Value) != originalVal
        ))

        btnTest.OnEvent("Click", (*) => (
            activeVal := Number(edit.Value),
            this.app.cfg.yMultiplier := activeVal,
            this.UpdateMenu(),
            btnTest.Enabled := false,
            btnApply.Enabled := activeVal != originalVal
        ))

        btnApply.OnEvent("Click", (*) => (
            this.app.cfg.yMultiplier := Number(edit.Value),
            this.UpdateMenu(),
            this.Save(Number(edit.Value)),
            g.Destroy()
        ))

        cancelAction := (*) => (
            this.app.cfg.yMultiplier := originalVal,
            this.UpdateMenu(),
            g.Destroy()
        )
        btnCancel.OnEvent("Click", cancelAction)
        g.OnEvent("Close", cancelAction)

        g.Show()
    }

    Validate(str) {
        val := 0
        try val := Number(str)
        return val >= 0.1 && val <= 20
    }

    Save(val) {
        configPath := A_ScriptDir "\config.json"
        try {
            jsonStr := FileRead(configPath, "UTF-8")
            jsonStr := RegExReplace(jsonStr, '("yMultiplier"\s*:\s*)[\d.]+', "${1}" Round(val, 2))
            FileDelete(configPath)
            FileAppend(jsonStr, configPath, "UTF-8")
        }
    }
}
