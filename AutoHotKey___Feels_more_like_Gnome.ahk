#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; SCRIPT: AutoHotKey___Feels_more_like_Gnome.ahk (WorkspacesSwitching-WIN-LINUX)
; VERSION: v2.5.0
; ==============================================================================
; CHANGELOG:
; - v2.5.0 (2026-10-19):
;   * Added Anti-Cheat Auto-Exit Guard (Anforderung I): checks on startup
;     (before hook installation) and polls every 1000ms passively via
;     ProcessExist() for Steam, Battle.net, Star Citizen (RSI Launcher / Client),
;     and Easy Anti-Cheat; safely releases LWin if held and exits silently
;     (ExitApp(0)) with no dialog so no AHK process or keyboard hook remains.
;   * Added Direct Workspace Switching 1..7 (Anforderung II): binds Left Ctrl +
;     Left Alt + 1..7 (<^<!1..7, preserving German AltGr+2/3/7) using pure
;     AHK v2 Registry lookup (HKCU\...\VirtualDesktops) and non-blocking stepped
;     navigation (WORKSPACE_JUMP_STEP_DELAY_MS := 30) with zero external DLLs.
;   * Refined TaskViewGroup to Windows 11 XamlExplorerHostIslandWindow only
;     (removed legacy Windows.UI.Core.CoreWindow to avoid shell flyout matches).
;   * Replaced always-active ~*Ctrl/Alt up release hotkeys with dynamic On/Off
;     toggling (SetWorkspaceReleaseHotkeys) only while IsWorkspaceSwitching.
;   * Lowered ProcessSetPriority from "High" to "AboveNormal".
; - v2.2.0 (2026-10-12):
;   * Switched to SendMode("Event") + SetKeyDelay(-1, -1) and A_MenuMaskKey
;     := "vkE8" to avoid SendInput hook churn/fallback lag and phantom Ctrl.
;   * Removed unused InstallMouseHook() (eliminates mouse lag & A_PriorKey
;     pollution from clicks/scrolls).
;   * Replaced synchronous #HotIf !WinActive(...) with hook-evaluated
;     HotIfWinNotActive(), replaced blocking KeyWait("LWin") with *LWin /
;     *LWin up state tracking, added logical Ctrl release tracking for
;     Deskflow compatibility, and made Task View search buffering asynchronous.
; - v2.1.3 (2026-05-18):
;   * Baseline script with Ctrl+Alt+Left/Right workspace switching, single/
;     double-tap LWin Task View / Start Menu proxy, Task View typing redirect,
;     and DevTools/VM exclusions.
; ==============================================================================

SendMode("Event")
SetKeyDelay(-1, -1)
A_MenuMaskKey := "vkE8"
try ProcessSetPriority("AboveNormal")
#HotIfTimeout 200

Global IsWorkspaceSwitching := false
Global IsWorkspaceJumping := false
Global JumpCurrentDesktop := 1
Global JumpTargetDesktop := 1
Global WORKSPACE_JUMP_STEP_DELAY_MS := 30
Global SearchTransitionActive := false
Global SearchBuffer := ""
Global LWinDown := false
Global LWinWasSolo := false
Global LWinCanDoubleTap := false
Global LastLWinTap := 0

Global AntiCheatGuardExes := [
    "steam.exe",
    "Battle.net.exe",
    "RSI Launcher.exe",
    "StarCitizen_Launcher.exe",
    "StarCitizen.exe",
    "EasyAntiCheat_EOS.exe",
    "EasyAntiCheat.exe"
]

; Check immediately before installing keyboard hook or registering hotkeys
CheckAntiCheatGuard()
SetTimer(CheckAntiCheatGuard, 1000)

InstallKeybdHook()

; ==============================================================================
; ANTI-CHEAT AUTO-EXIT GUARD
; ==============================================================================
CheckAntiCheatGuard() {
    Global AntiCheatGuardExes, IsWorkspaceSwitching, IsWorkspaceJumping, LWinDown

    for _, exe in AntiCheatGuardExes {
        if (ProcessExist(exe)) {
            SetTimer(RunWorkspaceJumpStep, 0)
            SetTimer(CheckWorkspaceRelease, 0)
            if (IsWorkspaceSwitching || IsWorkspaceJumping || LWinDown || GetKeyState("LWin")) {
                Send("{Blind}{vkE8}{LWin up}")
            }
            ExitApp(0)
        }
    }
}

; ==============================================================================
; TASK VIEW SEARCH HOTKEYS (Gnome-like Typing)
; ==============================================================================
; Bound strictly to Windows 11 Task View XAML island under explorer.exe
GroupAdd("TaskViewGroup", "ahk_class XamlExplorerHostIslandWindow ahk_exe explorer.exe")

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
; WORKSPACE SWITCH HOTKEYS (Relative Left/Right + Direct 1..7 via Registry)
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

; Direct jump 1..7 on Left Ctrl + Left Alt (keeps German AltGr+2/3/7 intact)
Loop 7 {
    Hotkey("<^<!" A_Index, SwitchToWorkspace.Bind(A_Index))
}
HotIfWinNotActive()

; Dynamic release hotkeys: enabled only while IsWorkspaceSwitching is active
Hotkey("~*LAlt up", EndWorkspaceSwitch, "Off")
Hotkey("~*RAlt up", EndWorkspaceSwitch, "Off")
Hotkey("~*LCtrl up", EndWorkspaceSwitch, "Off")
Hotkey("~*RCtrl up", EndWorkspaceSwitch, "Off")

SetWorkspaceReleaseHotkeys(state) {
    HotIf()
    Hotkey("~*LAlt up", EndWorkspaceSwitch, state)
    Hotkey("~*RAlt up", EndWorkspaceSwitch, state)
    Hotkey("~*LCtrl up", EndWorkspaceSwitch, state)
    Hotkey("~*RCtrl up", EndWorkspaceSwitch, state)
}

HandleWorkspaceSwitch(Direction) {
    Global IsWorkspaceSwitching, IsWorkspaceJumping

    if (IsWorkspaceJumping) {
        SetTimer(RunWorkspaceJumpStep, 0)
        IsWorkspaceJumping := false
    }

    if (!IsWorkspaceSwitching) {
        IsWorkspaceSwitching := true
        SetWorkspaceReleaseHotkeys("On")
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
    SetWorkspaceReleaseHotkeys("Off")
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

GetVirtualDesktopState() {
    baseKey := "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops"
    idsHex := RegRead(baseKey, "VirtualDesktopIDs", "")
    if (idsHex = "" || Mod(StrLen(idsHex), 32) != 0) {
        return { valid: false, current: 0, count: 0 }
    }

    desktopCount := StrLen(idsHex) // 32
    curHex := RegRead(baseKey, "CurrentVirtualDesktop", "")

    if (StrLen(curHex) != 32) {
        sessionId := 0
        if (DllCall("Kernel32\ProcessIdToSessionId", "UInt", ProcessExist(), "UInt*", &sessionId)) {
            sessionKey := "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\SessionInfo\" sessionId "\VirtualDesktops"
            curHex := RegRead(sessionKey, "CurrentVirtualDesktop", "")
        }
    }

    if (curHex = "") {
        return { valid: true, current: 1, count: desktopCount }
    }
    if (StrLen(curHex) != 32) {
        return { valid: false, current: 0, count: desktopCount }
    }

    Loop desktopCount {
        if (SubStr(idsHex, (A_Index - 1) * 32 + 1, 32) = curHex) {
            return { valid: true, current: A_Index, count: desktopCount }
        }
    }

    return { valid: false, current: 0, count: desktopCount }
}

SwitchToWorkspace(TargetIndex, *) {
    Global IsWorkspaceSwitching, IsWorkspaceJumping, JumpCurrentDesktop, JumpTargetDesktop

    if (IsWorkspaceSwitching) {
        EndWorkspaceSwitch()
    }

    state := GetVirtualDesktopState()
    if (!state.valid || TargetIndex < 1 || TargetIndex > state.count) {
        return
    }

    if (IsWorkspaceJumping) {
        JumpTargetDesktop := TargetIndex
        return
    }

    if (state.current = TargetIndex) {
        return
    }

    JumpCurrentDesktop := state.current
    JumpTargetDesktop := TargetIndex
    IsWorkspaceJumping := true
    SetTimer(RunWorkspaceJumpStep, -1)
}

RunWorkspaceJumpStep() {
    Global IsWorkspaceJumping, JumpCurrentDesktop, JumpTargetDesktop, WORKSPACE_JUMP_STEP_DELAY_MS

    if (!IsWorkspaceJumping || JumpCurrentDesktop = JumpTargetDesktop) {
        FinishWorkspaceJump()
        return
    }

    dir := (JumpTargetDesktop > JumpCurrentDesktop) ? "Right" : "Left"
    ctrlWasDown := GetKeyState("LCtrl") || GetKeyState("RCtrl")
    altUp := (GetKeyState("LAlt") ? "{LAlt up}" : "") . (GetKeyState("RAlt") ? "{RAlt up}" : "")
    prefix := "{Blind}" . (altUp != "" ? "{vkE8}" altUp : "") . (ctrlWasDown ? "" : "{LCtrl down}")
    suffix := "{LWin up}" . (ctrlWasDown ? "" : "{LCtrl up}")

    Send(prefix "{LWin down}{" dir "}" suffix)
    JumpCurrentDesktop += (dir = "Right") ? 1 : -1

    if (JumpCurrentDesktop = JumpTargetDesktop) {
        FinishWorkspaceJump()
    } else {
        SetTimer(RunWorkspaceJumpStep, -WORKSPACE_JUMP_STEP_DELAY_MS)
    }
}

FinishWorkspaceJump() {
    Global IsWorkspaceJumping

    IsWorkspaceJumping := false
    if (GetKeyState("LWin")) {
        Send("{Blind}{vkE8}{LWin up}")
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
