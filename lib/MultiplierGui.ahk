#Requires AutoHotkey v2.0

class MultiplierGui {
    __New(app, tray, labels) {
        this.app := app
        this.tray := tray
        this.labels := labels
    }

    MenuLabel() {
        return this.labels.menuPrefix Round(this.app.cfg.yMultiplier, 2) this.labels.menuSuffix
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

        g := Gui("+AlwaysOnTop", this.labels.windowTitle)
        g.SetFont("s10")
        g.Add("Text", , this.labels.inputLabel)
        edit := g.Add("Edit", "w280 vMultVal", Round(originalVal, 2))
        btnTest := g.Add("Button", "w280 Disabled Default", this.labels.btnTest)
        btnApply := g.Add("Button", "w280 Disabled", this.labels.btnApply)
        btnCancel := g.Add("Button", "w280", this.labels.btnCancel)

        validateInput := (*) => this.Validate(edit.Value)

        edit.OnEvent("Change", (*) => (
            btnTest.Enabled := validateInput() && Number(edit.Value) != activeVal,
            btnApply.Enabled := validateInput() && Number(edit.Value) != originalVal
        ))

        btnTest.OnEvent("Click", (*) => (
            activeVal := Number(edit.Value),
            this.app.cfg.yMultiplier := activeVal,
            this.UpdateMenu(),
            this.tray.UpdateTooltip(),
            btnTest.Enabled := false,
            btnApply.Enabled := activeVal != originalVal
        ))

        btnApply.OnEvent("Click", (*) => (
            this.app.cfg.yMultiplier := Number(edit.Value),
            this.UpdateMenu(),
            this.tray.UpdateTooltip(),
            this.Save(Number(edit.Value)),
            g.Destroy()
        ))

        cancelAction := (*) => (
            this.app.cfg.yMultiplier := originalVal,
            this.UpdateMenu(),
            this.tray.UpdateTooltip(),
            g.Destroy()
        )
        btnCancel.OnEvent("Click", cancelAction)
        g.OnEvent("Close", cancelAction)
        g.OnEvent("Escape", cancelAction)

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
