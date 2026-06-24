#Requires AutoHotkey v2.0

class FileDebugLog {
    ; The low-level mouse hook runs on this same (single) AHK thread, so any
    ; expensive work here stalls mouse delivery — a flush that exceeds the
    ; LowLevelHooksTimeout makes Windows drop events and the cursor stutters.
    ; Therefore the cost of logging must stay CONSTANT, independent of how large
    ; the log has grown:
    ;   - lines are appended to disk in small batches (never a full-file rewrite)
    ;   - the file is bounded by an O(1) rename-rotation, not a read/trim/rewrite
    ; Both are cheap enough to run inline in the hook callback without hitching.
    __New(enabled, filePath, maxLines := 128, sampleRate := 10) {
        this.enabled := enabled
        this.filePath := filePath
        this.maxLines := maxLines
        this.sampleRate := sampleRate
        this.buffer := []        ; lines not yet written to disk
        this.fileLines := 0      ; lines currently in the active log file
        this.sampleCount := 0
        if this.enabled {
            try FileDelete(this.filePath)          ; start each run with a fresh log
            try FileDelete(this.filePath ".1")
        }
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

        if this.buffer.Length >= 50
            this.Flush()
    }

    Flush() {
        if !this.enabled || !this.buffer.Length
            return

        text := ""
        for line in this.buffer
            text .= line "`n"
        try FileAppend(text, this.filePath, "UTF-8")
        this.fileLines += this.buffer.Length
        this.buffer := []

        ; Bound the file without ever reading/rewriting it: once it reaches the
        ; cap, rotate the current log to ".1" (an instant rename) and start a new
        ; one. At most ~2*maxLines lines are retained across the two files.
        if (this.fileLines >= this.maxLines) {
            try FileMove(this.filePath, this.filePath ".1", true)
            this.fileLines := 0
        }
    }
}
