; register and unregister new task for Task Scheduler © gihub.com/yakunins
#Requires AutoHotkey v2.0

PS := 'powershell.exe'
defaultUser := A_ComputerName . '\' . A_UserName

RegisterTaskOnStartup(taskName, executablePath, user := defaultUser, debug := false) {
    startupTrigger := "New-ScheduledTaskTrigger -AtStartup"
    groupId := user
    principal := "New-ScheduledTaskPrincipal -GroupId '" groupId "' -RunLevel Highest"

    cmd := "`""
        . (debug ? "try{" : "")
        . "Register-ScheduledTask -TaskName '" taskName "'"
        . " -Trigger (" startupTrigger ")"
        . " -User '" user "'"
        . " -RunLevel Highest"
        . " -Action (New-ScheduledTaskAction -Execute '" executablePath "')"
        . " -Force"
        . ";"
        . (debug ? "Write-Host 'RegisterTaskOnStartup() (" taskName ") done.';" : "")
        . (debug ? "}catch{" : "")
        . (debug ? "Write-Host 'RegisterTaskOnStartup() (" taskName ") error:';" : "")
        . (debug ? "Write-Host $_;" : "")
        . (debug ? "}" : "")
        . "`""

    if (debug) {
        try {
            A_Clipboard := cmd
        }
        Run(PS . ' -noexit -command ' . cmd)
        return
    }
    Run(PS . ' -command ' . cmd, , 'Hide')
}

UnregisterTask(taskName, debug := false) {
    cmd := "`""
        . (debug ? "try{" : "")
        . "Unregister-ScheduledTask -TaskName '" taskName "'"
        . " -Confirm:$false"
        . ";"
        . (debug ? "Write-Host 'UnregisterTask() (" taskName ") done.';" : "")
        . (debug ? "}catch{" : "")
        . (debug ? "Write-Host 'UnregisterTask() (" taskName ") error:';" : "")
        . (debug ? "Write-Host $_;" : "")
        . (debug ? "}" : "")
        . "`""

    if (debug) {
        try {
            A_Clipboard := cmd
        }
        Run(PS . ' -noexit -command ' . cmd)
        return
    }
    Run(PS . ' -command ' . cmd, , 'Hide')
}