#Requires AutoHotkey v2.0.23
#SingleInstance Force

; ==============================================================================
; gnome-hotkeys-for-windows (v2.6.0)
; Brings GNOME out-of-the-box keyboard navigation & workspace switching to Windows.
;
; Author:  Sven Dawitz
; Repo:    https://github.com/Sven-Dawitz/gnome-hotkeys-for-windows
; License: MIT (see LICENSE file)
; SPDX-License-Identifier: MIT
;
; See README.md for full documentation, hotkey overview, and changelog.
; ==============================================================================

; ==============================================================================
; USER CONFIGURATION
; ==============================================================================

; Gaming launchers & anti-cheat processes that trigger an immediate silent exit.
; Add any other launcher or game executable here to ensure AutoHotkey never runs
; alongside it. Note: boot-time drivers/tray icons such as Riot Vanguard's
; vgtray.exe / vgc.exe are intentionally omitted so the script can run on desktop
; (RiotClientServices.exe triggers exit as soon as Riot Client starts).
global AntiCheatGuards := [
    ; --- Game Launchers ---
    "steam.exe",                           ; Steam
    "EpicGamesLauncher.exe",               ; Epic Games Launcher
    "Battle.net.exe",                      ; Blizzard Battle.net
    "EADesktop.exe",                       ; EA App
    "upc.exe",                             ; Ubisoft Connect
    "RiotClientServices.exe",              ; Riot Client (Valorant / League of Legends)
    "RSI Launcher.exe",                    ; Star Citizen (RSI Launcher)
    "faceitclient.exe",                    ; FACEIT Client
    ; --- Game Clients & Anti-Cheat Engines (Safety Net) ---
    "StarCitizen_Launcher.exe",            ; Star Citizen Bootstrapper
    "StarCitizen.exe",                     ; Star Citizen Game Client
    "EasyAntiCheat_EOS.exe",               ; Easy Anti-Cheat (EOS)
    "EasyAntiCheat.exe",                   ; Easy Anti-Cheat (Legacy)
    "BEService.exe",                       ; BattlEye Service
    "EAAntiCheat.GameServiceLauncher.exe", ; EA AntiCheat (Javelin)
    "GameMon.des"                          ; nProtect GameGuard (e.g. Helldivers 2)
]

; Fullscreen VMs / remote desktop viewers where ALL custom hotkeys (including Win,
; workspace switching, and Ctrl+Alt+T) are disabled so the guest OS receives them
; natively.
global ExcludedApps := [
    "vmware.exe",                ; VMware Workstation / Player
    "VirtualBoxVM.exe",          ; Oracle VirtualBox
    "vmconnect.exe",             ; Windows Hyper-V VM Connection
    "qemu-system-x86_64.exe",    ; QEMU (64-bit)
    "remote-viewer.exe",         ; SPICE / virt-viewer (Proxmox / KVM)
    "mstsc.exe"                  ; Windows Remote Desktop (comment out if used windowed)
]

; Delay (ms) between steps when jumping across multiple virtual desktops
; (Left Ctrl + Left Alt + 1..7). Can be lowered (e.g. 15) if Windows animation
; effects are disabled.
global WORKSPACE_JUMP_STEP_DELAY_MS := 30

; ==============================================================================
; RUNTIME SETTINGS & INTERNAL STATE
; ==============================================================================
SendMode("Event")
SetKeyDelay(-1, -1)
A_MenuMaskKey := "vkE8"
try ProcessSetPriority("AboveNormal")
#HotIfTimeout 200

global IsWorkspaceSwitching := false
global IsWorkspaceJumping := false
global JumpCurrentDesktop := 1
global JumpTargetDesktop := 1
global SearchTransitionActive := false
global SearchBuffer := ""
global SearchHook := ""
global SearchHookMode := "" ; "", "PreCapture", or "Transition"
global SearchAborted := false
global PreCaptureStartTick := 0
global LWinDown := false
global LWinWasSolo := false
global LWinCanDoubleTap := false
global LastLWinTap := 0

; Run anti-cheat guard immediately before installing the keyboard hook or hotkeys
CheckAntiCheatGuard()
SetTimer(CheckAntiCheatGuard, 1000)

InstallKeybdHook()

; ==============================================================================
; ANTI-CHEAT AUTO-EXIT GUARD
; ==============================================================================
CheckAntiCheatGuard() {
    global AntiCheatGuards, IsWorkspaceSwitching, IsWorkspaceJumping, LWinDown

    for _, exe in AntiCheatGuards {
        if (ProcessExist(exe)) {
            SetTimer(RunWorkspaceJumpStep, 0)
            SetTimer(CheckWorkspaceRelease, 0)
            StopSearchHook()
            if (IsWorkspaceSwitching || IsWorkspaceJumping || LWinDown || GetKeyState("LWin")) {
                Send("{Blind}{vkE8}{LWin up}")
            }
            ExitApp(0)
        }
    }
}

; ==============================================================================
; WINDOW GROUPS & TASK VIEW SEARCH HOTKEYS
; ==============================================================================
; Bound strictly to the Windows 11 Task View XAML island under explorer.exe
GroupAdd("TaskViewGroup", "ahk_class XamlExplorerHostIslandWindow ahk_exe explorer.exe")
GroupAdd("StartMenuGroup", "ahk_exe StartMenuExperienceHost.exe")
GroupAdd("StartMenuGroup", "ahk_exe SearchHost.exe")

for _, exe in ExcludedApps {
    GroupAdd("ExcludedApps", "ahk_exe " exe)
}

HotIfWinActive("ahk_group TaskViewGroup")

; A-Z
loop 26 {
    Hotkey(Chr(A_Index + 96), TriggerSearch)
}
; 0-9
loop 10 {
    Hotkey(String(A_Index - 1), TriggerSearch)
}
; German umlauts and Eszett (safely skipped on keyboard layouts without them)
for _, ch in ["ä", "ö", "ü", "ß"] {
    try Hotkey(ch, TriggerSearch)
}

HotIfWinActive()

; ==============================================================================
; CUSTOM HOTKEYS (ALL DISABLED INSIDE ExcludedApps)
; ==============================================================================
HotIfWinNotActive("ahk_group ExcludedApps")

; Relative virtual desktop switching
Hotkey("^!Left", (*) => HandleWorkspaceSwitch("Left"))
Hotkey("^!Right", (*) => HandleWorkspaceSwitch("Right"))

; Direct jump to workspaces 1..7 on Left Ctrl + Left Alt (preserves AltGr+2/3/7)
loop 7 {
    Hotkey("<^<!" A_Index, SwitchToWorkspace.Bind(A_Index))
}

; Open modern Windows Terminal (falls back to PowerShell if unavailable)
Hotkey("^!t", OpenTerminal)

; GNOME-like Super (LWin) overview / type-to-search / double-tap Start Menu
Hotkey("*LWin", HandleLWinDown)

HotIfWinNotActive()

; Dynamic release hotkeys: enabled only while their corresponding hold is active
Hotkey("~*LAlt up", EndWorkspaceSwitch, "Off")
Hotkey("~*RAlt up", EndWorkspaceSwitch, "Off")
Hotkey("~*LCtrl up", EndWorkspaceSwitch, "Off")
Hotkey("~*RCtrl up", EndWorkspaceSwitch, "Off")
Hotkey("*LWin up", HandleLWinUp, "Off")

; ==============================================================================
; TERMINAL LAUNCHER (Ctrl+Alt+T)
; ==============================================================================
OpenTerminal(*) {
    CancelPreCapture()
    try {
        Run("wt.exe")
    } catch {
        try Run("powershell.exe")
    }
}

; ==============================================================================
; WORKSPACE SWITCHING (Relative Left/Right + Direct 1..7 via Registry)
; ==============================================================================
SetWorkspaceReleaseHotkeys(state) {
    HotIf()
    Hotkey("~*LAlt up", EndWorkspaceSwitch, state)
    Hotkey("~*RAlt up", EndWorkspaceSwitch, state)
    Hotkey("~*LCtrl up", EndWorkspaceSwitch, state)
    Hotkey("~*RCtrl up", EndWorkspaceSwitch, state)
}

HandleWorkspaceSwitch(Direction) {
    global IsWorkspaceSwitching, IsWorkspaceJumping

    CancelPreCapture()

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
    global IsWorkspaceSwitching

    if (!IsWorkspaceSwitching) {
        return
    }
    IsWorkspaceSwitching := false
    SetTimer(CheckWorkspaceRelease, 0)
    SetWorkspaceReleaseHotkeys("Off")
    Send("{Blind}{vkE8}{LWin up}")
}

CheckWorkspaceRelease() {
    global IsWorkspaceSwitching

    if (!IsWorkspaceSwitching) {
        SetTimer(CheckWorkspaceRelease, 0)
        return
    }
    ; Check logical Ctrl state (without "P") so software-injected modifiers work reliably
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

    ; Before the first switch after boot, CurrentVirtualDesktop may not exist yet -> Desktop 1
    if (curHex = "") {
        return { valid: true, current: 1, count: desktopCount }
    }
    if (StrLen(curHex) != 32) {
        return { valid: false, current: 0, count: desktopCount }
    }

    loop desktopCount {
        if (SubStr(idsHex, (A_Index - 1) * 32 + 1, 32) = curHex) {
            return { valid: true, current: A_Index, count: desktopCount }
        }
    }

    return { valid: false, current: 0, count: desktopCount }
}

SwitchToWorkspace(TargetIndex, *) {
    global IsWorkspaceSwitching, IsWorkspaceJumping, JumpCurrentDesktop, JumpTargetDesktop

    CancelPreCapture()

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
    global IsWorkspaceJumping, JumpCurrentDesktop, JumpTargetDesktop, WORKSPACE_JUMP_STEP_DELAY_MS

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
    global IsWorkspaceJumping

    IsWorkspaceJumping := false
    if (GetKeyState("LWin")) {
        Send("{Blind}{vkE8}{LWin up}")
    }
}

; ==============================================================================
; WINDOWS KEY MODIFICATION (Non-Blocking Tap / Double-Tap / Modifier Proxy)
; ==============================================================================
HandleLWinDown(*) {
    global LWinDown, LWinWasSolo, LWinCanDoubleTap

    ; Ignore OS auto-repeat while held, but recover after Win+L lock screen
    if (LWinDown && GetKeyState("LWin")) {
        return
    }

    CancelPreCapture()
    LWinDown := true
    LWinWasSolo := !(GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("Shift"))
    LWinCanDoubleTap := (A_PriorKey = "LWin")

    HotIf()
    Hotkey("*LWin up", HandleLWinUp, "On")
    Send("{Blind}{LWin down}")
}

HandleLWinUp(*) {
    global LWinDown, LWinWasSolo, LWinCanDoubleTap, LastLWinTap

    HotIf()
    Hotkey("*LWin up", HandleLWinUp, "Off")

    wasDown := LWinDown
    wasSolo := LWinWasSolo
    canDoubleTap := LWinCanDoubleTap
    LWinDown := false
    LWinWasSolo := false
    LWinCanDoubleTap := false

    if (!wasDown) {
        return
    }

    if (wasSolo && A_PriorKey = "LWin") {
        now := A_TickCount
        if (canDoubleTap && LastLWinTap > 0 && (now - LastLWinTap) < 400) {
            ; --- QUICK DOUBLE-TAP: Open native Start Menu directly ---
            LastLWinTap := 0
            StopSearchHook()
            Send("{Blind}{vkE8}{LWin up}")
            SetTimer(OpenStartMenuAfterTaskView, -1)
        } else {
            ; --- SINGLE TAP: Toggle Task View (window & desktop overview) ---
            LastLWinTap := now
            openingOverview := !WinActive("ahk_group TaskViewGroup")
            Send("{Blind}{Tab}{LWin up}")
            if (openingOverview) {
                StartPreCapture()
            } else {
                StopSearchHook()
            }
        }
    } else {
        ; --- MODIFIER USAGE (e.g., Win+E, Win+L, Win+Shift+S) ---
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
; SEARCH CAPTURE & START MENU REDIRECT (Pre-Capture + 2-Stage InputHook)
; ==============================================================================
StartPreCapture() {
    global SearchHook, SearchHookMode, SearchBuffer, SearchAborted, PreCaptureStartTick

    StopSearchHook()
    SearchBuffer := ""
    SearchAborted := false
    SearchHookMode := "PreCapture"
    PreCaptureStartTick := A_TickCount

    ih := InputHook("B I1 T2.5")
    ih.VisibleText := false
    ih.VisibleNonText := true
    ih.NotifyNonText := true
    ih.OnChar := OnSearchHookChar
    ih.OnKeyDown := OnSearchHookKeyDown
    ih.OnEnd := OnSearchHookEnd
    SearchHook := ih
    ih.Start()

    SetTimer(ExpirePreCapture, 50)
}

CancelPreCapture() {
    global SearchHookMode

    if (SearchHookMode = "PreCapture") {
        StopSearchHook()
    }
}

ExpirePreCapture() {
    global SearchHookMode, PreCaptureStartTick

    if (SearchHookMode != "PreCapture") {
        SetTimer(ExpirePreCapture, 0)
        return
    }
    if (WinActive("ahk_group TaskViewGroup") || (A_TickCount - PreCaptureStartTick) >= 350) {
        StopSearchHook()
    }
}

StartTransitionCapture(InitialChar) {
    global SearchTransitionActive, SearchAborted, SearchBuffer, SearchHookMode, SearchHook

    StopSearchHook()
    SearchTransitionActive := true
    SearchAborted := false
    SearchBuffer := InitialChar
    SearchHookMode := "Transition"

    ih := InputHook("B I1 T2.5")
    ih.VisibleText := false
    ih.VisibleNonText := true
    ih.NotifyNonText := true
    ih.OnChar := OnSearchHookChar
    ih.OnKeyDown := OnSearchHookKeyDown
    ih.OnEnd := OnSearchHookEnd
    ih.KeyOpt("{Backspace}{Enter}", "S")
    SearchHook := ih
    ih.Start()
}

StopSearchHook() {
    global SearchHook, SearchHookMode

    SetTimer(ExpirePreCapture, 0)
    ih := SearchHook
    SearchHook := ""
    SearchHookMode := ""
    if (IsObject(ih) && ih.InProgress) {
        ih.Stop()
    }
}

OnSearchHookChar(ih, char) {
    global SearchHook, SearchHookMode, SearchTransitionActive, SearchAborted, SearchBuffer, LastLWinTap

    if (ih != SearchHook) {
        return
    }

    ; Ignore non-printable control chars and shortcut modifiers (keep AltGr = LCtrl+RAlt working)
    hasShortcutMod := (GetKeyState("LCtrl") && !GetKeyState("RAlt")) || GetKeyState("RCtrl") || GetKeyState("LAlt") ||
    GetKeyState("LWin") || GetKeyState("RWin")
    if (Ord(char) < 32 || hasShortcutMod) {
        return
    }

    if (SearchHookMode = "PreCapture") {
        ; Do not start search on a stray leading space
        if (Ord(char) = 32) {
            return
        }
        ; Upgrade the running hook in-place to Transition mode with zero gap
        SetTimer(ExpirePreCapture, 0)
        LastLWinTap := 0
        SearchHookMode := "Transition"
        SearchTransitionActive := true
        SearchAborted := false
        SearchBuffer := char
        ih.KeyOpt("{Backspace}{Enter}", "S")
        SetTimer(DoSearchTransition, -1)
    } else if (SearchHookMode = "Transition") {
        SearchBuffer .= char
    }
}

OnSearchHookKeyDown(ih, vk, sc) {
    global SearchHook, SearchHookMode, SearchAborted, SearchBuffer

    if (ih != SearchHook) {
        return
    }

    if (vk = 0x1B) { ; Escape
        if (SearchHookMode = "Transition") {
            SearchAborted := true
        }
        StopSearchHook()
        return
    }

    if (SearchHookMode = "PreCapture") {
        ; Cancel Pre-Capture on navigation/action keys (never on Shift)
        if (vk = 0x08 || vk = 0x09 || vk = 0x0D || (vk >= 0x25 && vk <= 0x28) || vk = 0x2E) {
            StopSearchHook()
        }
    } else if (SearchHookMode = "Transition") {
        if (vk = 0x08 && StrLen(SearchBuffer) > 0) { ; Backspace
            SearchBuffer := SubStr(SearchBuffer, 1, -1)
        }
    }
}

OnSearchHookEnd(ih) {
    global SearchHook, SearchHookMode

    if (ih != SearchHook) {
        return
    }
    SetTimer(ExpirePreCapture, 0)
    if (SearchHookMode = "PreCapture") {
        SearchHookMode := ""
    }
}

TriggerSearch(ThisHotkey) {
    global SearchTransitionActive, SearchBuffer, LastLWinTap

    LastLWinTap := 0
    if (SearchTransitionActive) {
        SearchBuffer .= ThisHotkey
        return
    }

    StartTransitionCapture(ThisHotkey)
    SetTimer(DoSearchTransition, -1)
}

DoSearchTransition() {
    global SearchTransitionActive, SearchBuffer, SearchAborted

    try {
        ; 1. Wait briefly if Task View was just triggered via Pre-Capture
        if (!WinActive("ahk_group TaskViewGroup")) {
            WinWaitActive("ahk_group TaskViewGroup", , 0.25)
        }
        if (SearchAborted) {
            return
        }

        ; 2. Close Task View (window overview)
        if (WinActive("ahk_group TaskViewGroup")) {
            Send("{Esc}")
            WinWaitNotActive("ahk_group TaskViewGroup", , 0.8)
        }
        if (SearchAborted) {
            return
        }

        ; 3. Open native Start Menu (Ctrl+Esc)
        Send("^{Esc}")
        WinWaitActive("ahk_group StartMenuGroup", , 1.0)
        if (SearchAborted) {
            return
        }
        Sleep(60)
        if (SearchAborted) {
            return
        }

        ; 4. Stage 1 -> Stage 2 hand-off (StartMenuExperienceHost -> SearchHost)
        ; Thread-local SetKeyDelay avoids touching the clipboard
        SetKeyDelay(10, 5)
        if (WinActive("ahk_exe StartMenuExperienceHost.exe") && StrLen(SearchBuffer) >= 1) {
            Critical("On")
            firstChar := SubStr(SearchBuffer, 1, 1)
            SearchBuffer := SubStr(SearchBuffer, 2)
            Critical("Off")
            SendText(firstChar)
            WinWaitActive("ahk_exe SearchHost.exe", , 0.8)
            Sleep(60)
        }
        if (SearchAborted) {
            return
        }

        ; 5. Flush remaining captured characters while InputHook continues catching tail input
        loop 10 {
            if (SearchAborted) {
                break
            }
            Critical("On")
            chunk := SearchBuffer
            SearchBuffer := ""
            Critical("Off")
            if (chunk = "") {
                break
            }
            SendText(chunk)
        }
    } finally {
        StopSearchHook()
        SearchBuffer := ""
        SearchAborted := false
        SearchTransitionActive := false
    }
}
