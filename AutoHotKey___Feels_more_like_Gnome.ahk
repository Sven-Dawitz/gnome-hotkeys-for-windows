#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; SCRIPT: AutoHotKey___Feels_more_like_Gnome.ahk (WorkspacesSwitching-WIN-LINUX)
; VERSION: v2.2.0 (Non-Blocking Hooks, Deskflow-Safe Modifiers & Fast SendEvent)
; ==============================================================================
; ARCHITECTURE:
; 1. Hook & Send Stability:
;    - Uses SendMode("Event") with SetKeyDelay(-1, -1) so Send never uninstalls/
;      reinstalls the low-level keyboard hook or falls back to 10ms-per-key delays.
;    - Sets A_MenuMaskKey to unassigned vkE8 to avoid phantom Ctrl masking.
;    - Keeps only the keyboard hook (no mouse hook overhead or A_PriorKey noise).
; 2. Fluid Workspace Switching (Ctrl+Alt+Left/Right -> Ctrl+Win+Left/Right):
;    - Uses hook-evaluated HotIfWinNotActive("ahk_group DevTools") and immediate
;      passthrough modifier-up hotkeys plus a logical-Ctrl safety timer so both
;      local hardware and Deskflow-injected modifiers release cleanly.
; 3. Gnome-Style Super Key (LWin Tap / Double-Tap / Modifier Proxy):
;    - Non-blocking *LWin / *LWin up state tracking (no KeyWait stall):
;      * Single tap: opens Task View (Win+Tab).
;      * Double tap (<400ms): closes Task View and opens native Start Menu.
;      * Hold + key: passes through as a normal Win modifier.
; 4. Task View Search Redirection:
;    - Typing [a-z, 0-9] in Task View buffers keystrokes asynchronously via timer
;      and flushes them literally via SendText into the native Start Menu.
; ==============================================================================

SendMode("Event")
SetKeyDelay(-1, -1)
A_MenuMaskKey := "vkE8"
try ProcessSetPriority("High")
#HotIfTimeout 200

InstallKeybdHook()

Global IsWorkspaceSwitching := false
Global SearchTransitionActive := false
Global SearchBuffer := ""
Global LWinDown := false
Global LWinWasSolo := false
Global LWinCanDoubleTap := false
Global LastLWinTap := 0

; ==============================================================================
; TASK VIEW SEARCH HOTKEYS (Gnome-like Typing)
; ==============================================================================
; Bound strictly to explorer.exe to avoid recursive triggering in Start Menu
GroupAdd("TaskViewGroup", "ahk_class XamlExplorerHostIslandWindow ahk_exe explorer.exe")
GroupAdd("TaskViewGroup", "ahk_class Windows.UI.Core.CoreWindow ahk_exe explorer.exe")

HotIfWinActive("ahk_group TaskViewGroup")

; A-Z
Loop 26 {
    Hotkey(Chr(A_Index + 96), TriggerSearch)
}
; 0-9
Loop 10 {
    Hotkey(String(A_Index - 1), TriggerSearch)
}

HotIfWinActive()

; ==============================================================================
; WORKSPACE SWITCH HOTKEYS (Non-Blocking State Machine + Immediate Release)
; ==============================================================================
exeList := [
    "idea64.exe",       ; JetBrains
    "pycharm64.exe",    ; PyCharm
    "Code.exe",         ; VS Code
    "mstsc.exe",        ; Windows Remote Desktop
    "vmware.exe",       ; VMware Workstation/Player
    "VirtualBoxVM.exe"  ; VirtualBox
]

for _, exe in exeList {
    GroupAdd("DevTools", "ahk_exe " exe)
}

HotIfWinNotActive("ahk_group DevTools")
Hotkey("^!Left", (*) => HandleWorkspaceSwitch("Left"))
Hotkey("^!Right", (*) => HandleWorkspaceSwitch("Right"))
HotIfWinNotActive()

; Immediate release when any Ctrl/Alt side is released (works for local & Deskflow)
~*LAlt up::EndWorkspaceSwitch()
~*RAlt up::EndWorkspaceSwitch()
~*LCtrl up::EndWorkspaceSwitch()
~*RCtrl up::EndWorkspaceSwitch()

HandleWorkspaceSwitch(Direction) {
    Global IsWorkspaceSwitching

    if (!IsWorkspaceSwitching) {
        IsWorkspaceSwitching := true
        altUp := (GetKeyState("LAlt") ? "{LAlt up}" : "") . (GetKeyState("RAlt") ? "{RAlt up}" : "")
        Send("{Blind}{vkE8}" altUp "{LWin down}{" Direction "}")
        SetTimer(CheckWorkspaceRelease, 50)
    } else {
        Send("{Blind}{" Direction "}")
    }
}

EndWorkspaceSwitch(*) {
    Global IsWorkspaceSwitching

    if (!IsWorkspaceSwitching) {
        return
    }
    IsWorkspaceSwitching := false
    SetTimer(CheckWorkspaceRelease, 0)
    Send("{Blind}{vkE8}{LWin up}")
}

CheckWorkspaceRelease() {
    Global IsWorkspaceSwitching

    if (!IsWorkspaceSwitching) {
        SetTimer(CheckWorkspaceRelease, 0)
        return
    }
    ; Check logical Ctrl state (without "P") so Deskflow-injected modifiers work reliably
    if (!GetKeyState("Ctrl")) {
        EndWorkspaceSwitch()
    }
}

; ==============================================================================
; WINDOWS KEY MODIFICATION (Non-Blocking Tap / Double-Tap / Proxy)
; ==============================================================================
*LWin:: {
    Global LWinDown, LWinWasSolo, LWinCanDoubleTap

    ; Ignore OS auto-repeat while held, but recover after Win+L lock screen
    if (LWinDown && GetKeyState("LWin")) {
        return
    }

    LWinDown := true
    LWinWasSolo := !(GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("Shift"))
    LWinCanDoubleTap := (A_PriorKey = "LWin")
    Send("{Blind}{LWin down}")
}

*LWin up:: {
    Global LWinDown, LWinWasSolo, LWinCanDoubleTap, LastLWinTap

    wasDown := LWinDown
    wasSolo := LWinWasSolo
    canDoubleTap := LWinCanDoubleTap
    LWinDown := false
    LWinWasSolo := false
    LWinCanDoubleTap := false

    if (wasDown && wasSolo && A_PriorKey = "LWin") {
        now := A_TickCount
        if (canDoubleTap && LastLWinTap > 0 && (now - LastLWinTap) < 400) {
            ; --- DOUBLE TAP: Direct Start Menu ---
            LastLWinTap := 0
            Send("{Blind}{vkE8}{LWin up}")
            SetTimer(OpenStartMenuAfterTaskView, -1)
        } else {
            ; --- SINGLE TAP: Open Task View ---
            LastLWinTap := now
            Send("{Blind}{Tab}{LWin up}")
        }
    } else {
        ; --- MODIFIER USAGE (e.g., Win+E) ---
        Send("{Blind}{LWin up}")
    }
}

OpenStartMenuAfterTaskView() {
    if (WinActive("ahk_group TaskViewGroup")) {
        Send("{Esc}")
        WinWaitNotActive("ahk_group TaskViewGroup", , 0.5)
    } else {
        Send("{Esc}")
        Sleep(50)
    }
    Send("^{Esc}")
}

; ==============================================================================
; HELPER FUNCTIONS (Asynchronous Search Interception & Buffering)
; ==============================================================================
TriggerSearch(ThisHotkey) {
    Global SearchTransitionActive, SearchBuffer, LastLWinTap

    LastLWinTap := 0
    if (SearchTransitionActive) {
        SearchBuffer .= ThisHotkey
        return
    }

    SearchTransitionActive := true
    SearchBuffer := ThisHotkey
    SetTimer(DoSearchTransition, -1)
}

DoSearchTransition() {
    Global SearchBuffer

    ; 1. Kill Task View
    Send("{Esc}")

    ; 2. Wait until Task View loses focus
    WinWaitNotActive("ahk_group TaskViewGroup", , 0.8)

    ; 3. Open native Start Menu
    Send("^{Esc}")

    ; 4. UI-Sleep for search host allocation
    Sleep(150)

    ; 5. Flush buffered text literally
    buf := SearchBuffer
    SearchBuffer := ""
    if (buf != "") {
        SendText(buf)
    }

    ; 6. Drain any trailing keystrokes and release lock
    SetTimer(ResetSearchState, -250)
}

ResetSearchState() {
    Global SearchTransitionActive, SearchBuffer

    buf := SearchBuffer
    SearchBuffer := ""
    if (buf != "") {
        SendText(buf)
    }
    SearchTransitionActive := false
}
