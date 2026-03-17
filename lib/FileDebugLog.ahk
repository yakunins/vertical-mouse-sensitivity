#Requires AutoHotkey v2.0

class FileDebugLog {
    __New(enabled, filePath, maxLines := 128, sampleRate := 10) {
        this.enabled := enabled
        this.filePath := filePath
        this.maxLines := maxLines
        this.sampleRate := sampleRate
        this.buffer := []
        this.writeCount := 0
        this.sampleCount := 0
    }

    Add(message, sampled := false) {
        if !this.enabled
            return

        if sampled {
            this.sampleCount++
            if Mod(this.sampleCount, this.sampleRate) != 0
                return
        }

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        this.buffer.Push("[" timestamp "] " message)

        while this.buffer.Length > this.maxLines
            this.buffer.RemoveAt(1)

        this.writeCount++
        if this.writeCount >= 50
            this.Flush()
    }

    Flush() {
        if !this.enabled || !this.buffer.Length
            return
        text := ""
        for line in this.buffer
            text .= line "`n"
        try FileOpen(this.filePath, "w", "UTF-8").Write(text)
        this.writeCount := 0
    }
}
