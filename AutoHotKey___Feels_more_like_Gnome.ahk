#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; SCRIPT: AutoHotKey___Feels_more_like_Gnome.ahk (WorkspacesSwitching-WIN-LINUX)
; VERSION: v2.5.1
; ==============================================================================
; ZIEL & SETUP:
; Dieses Skript bringt das gewohnte GNOME-Out-of-the-Box-Navigationsgefühl auf
; Windows 11, damit über alle Betriebssysteme hinweg dieselbe Muscle Memory gilt.
;
; 3-Geräte-Setup über Deskflow (1x Tastatur & Maus für alle drei Systeme):
;   [Links: Debian 13 Laptop] <-> [Mitte: Windows 11 (Tastatur-/Maus-Host)] <-> [Rechts: Arch Linux Laptop]
; Hinweis zur Zwischenablage: Das Teilen der Zwischenablage läuft über
; KDE Connect (bzw. das GNOME-Pendant GSConnect), da Clipboard-Sharing in
; Deskflow nach den Wayland-Anpassungen noch nicht zuverlässig funktioniert.
; Dieses Skript rührt die Zwischenablage (A_Clipboard) daher bewusst NIE an.
;
; FEATURES & HOTKEYS:
; - <Win> (kurz tippen):
;     Öffnet/schließt die Fenster-Übersicht (Windows „Task View“ / Win+Tab),
;     analog zur GNOME-Activities-Übersicht.
; - <Win> + direkt oder verzögert lostippen:
;     Fängt alle getippten Zeichen lückenlos per unterdrückendem InputHook ab
;     (inkl. Pre-Capture direkt nach <Win>, Umlauten ä/ö/ü/ß, Backspace-Korrektur
;     und Abbruch per Esc), schließt die Fenster-Übersicht, öffnet das
;     Startmenü (Strg+Esc / SearchHost.exe) und tippt den Puffer ohne Verlust
;     ins Suchfeld – ohne die Zwischenablage anzufassen.
; - <Win> (Doppeltippen < 400 ms):
;     Öffnet direkt das native Windows-Startmenü.
; - <Win> + Taste gedrückt halten (z. B. Win+E, Win+L, Win+Shift+S):
;     Verhält sich wie die normale Windows-Modifier-Taste.
; - Strg + Alt + Links / Rechts:
;     Wechselt einen virtuellen Desktop nach links bzw. rechts (mit sauberem
;     Modifier-Release für Deskflow-Clients/Host).
; - Linke Strg + Linke Alt + 1..7:
;     Springt direkt zu Workspace 1..7 via Windows-11-Registry (Zero-DLL).
;     Bewusst auf Linke Strg + Linke Alt (<^<!) gebunden, damit deutsches
;     AltGr+2 (²), AltGr+3 (³) und AltGr+7 ({) unverändert funktionieren.
; - DevTools- & VM-Ausnahmen:
;     In idea64.exe, pycharm64.exe, Code.exe, mstsc.exe, vmware.exe und
;     VirtualBoxVM.exe bleiben alle Workspace-Hotkeys unangetastet.
; - Anti-Cheat Auto-Exit Guard:
;     Prüft beim Start (noch vor Hook-Installation) sowie alle 1000 ms passiv
;     per ProcessExist() auf Steam, Battle.net, Star Citizen (RSI Launcher /
;     Client) und Easy Anti-Cheat; gibt ggf. LWin frei und beendet sich
;     lautlos (ExitApp(0)) ohne Popup, damit kein AHK-Prozess/Hook verbleibt.
; - Hook- & Latenz-Optimierung:
;     SendMode("Event") + SetKeyDelay(-1, -1) global, A_MenuMaskKey := "vkE8",
;     kein Mouse-Hook, ProcessSetPriority("AboveNormal"), Hook-ausgewertetes
;     HotIfWinNotActive() und dynamische Release-Hotkeys (nur aktiv beim Wechsel).
;
; CHANGELOG:
; - v2.5.1 (2026-10-26):
;   * Fixed dropped characters when typing rapidly after <Win>: replaced the
;     TaskViewGroup-only hotkey buffering with a continuous InputHook ("B I1 T2.5")
;     featuring Pre-Capture right after opening the overview, zero-gap upgrade
;     to Transition capture, Backspace/Esc support, and a 2-stage Start Menu
;     (StartMenuExperienceHost.exe -> SearchHost.exe) flush using thread-local
;     SetKeyDelay(10, 5) without touching the clipboard (KDE Connect safe).
;   * Added German umlaut/ß hotkeys (ä, ö, ü, ß) to TaskViewGroup.
;   * Added full German feature/hotkey overview and 3-device Deskflow +
;     KDE Connect/GSConnect setup documentation to header.
; - v2.5.0 (2026-10-19):
;   * Added Anti-Cheat Auto-Exit Guard (startup check + 1000ms ProcessExist()
;     polling + silent ExitApp(0) for Steam, Battle.net, Star Citizen, EAC).
;   * Added Direct Workspace Switching 1..7 via <^<!1..7 using pure AHK v2
;     Registry lookup (HKCU\...\VirtualDesktops) and non-blocking 30ms steps.
;   * Narrowed TaskViewGroup to Windows 11 XamlExplorerHostIslandWindow only.
;   * Switched ~*Ctrl/Alt up release hotkeys to dynamic On/Off toggling.
;   * Lowered ProcessSetPriority from "High" to "AboveNormal".
; - v2.2.0 (2026-10-12):
;   * Switched to SendMode("Event") + SetKeyDelay(-1, -1) and vkE8 menu mask.
;   * Removed unused InstallMouseHook() (eliminated mouse lag & A_PriorKey noise).
;   * Replaced #HotIf with HotIfWinNotActive(), replaced KeyWait("LWin") with
;     *LWin / *LWin up state tracking, and used logical Ctrl check for Deskflow.
; - v2.1.3 (2026-05-18):
;   * Baseline script (workspace switch state machine, Super tap/double-tap,
;     Task View search redirect, DevTools/VM exceptions).
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
Global SearchHook := ""
Global SearchHookMode := "" ; "", "PreCapture", or "Transition"
Global SearchAborted := false
Global PreCaptureStartTick := 0
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
            StopSearchHook()
            if (IsWorkspaceSwitching || IsWorkspaceJumping || LWinDown || GetKeyState("LWin")) {
                Send("{Blind}{vkE8}{LWin up}")
            }
            ExitApp(0)
        }
    }
}

; ==============================================================================
; TASK VIEW & START MENU SEARCH GROUPS / HOTKEYS (Gnome-like Typing)
; ==============================================================================
; Bound strictly to Windows 11 Task View XAML island under explorer.exe
GroupAdd("TaskViewGroup", "ahk_class XamlExplorerHostIslandWindow ahk_exe explorer.exe")
GroupAdd("StartMenuGroup", "ahk_exe StartMenuExperienceHost.exe")
GroupAdd("StartMenuGroup", "ahk_exe SearchHost.exe")

HotIfWinActive("ahk_group TaskViewGroup")

; A-Z
Loop 26 {
    Hotkey(Chr(A_Index + 96), TriggerSearch)
}
; 0-9
Loop 10 {
    Hotkey(String(A_Index - 1), TriggerSearch)
}
; German umlauts & Eszett
for _, ch in ["ä", "ö", "ü", "ß"] {
    try Hotkey(ch, TriggerSearch)
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

    CancelPreCapture()
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
            StopSearchHook()
            Send("{Blind}{vkE8}{LWin up}")
            SetTimer(OpenStartMenuAfterTaskView, -1)
        } else {
            ; --- SINGLE TAP: Toggle Fenster-Übersicht (Task View) ---
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
; SEARCH CAPTURE & START MENU REDIRECT (Pre-Capture + 2-Stage InputHook)
; ==============================================================================
StartPreCapture() {
    Global SearchHook, SearchHookMode, SearchBuffer, SearchAborted, PreCaptureStartTick

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
    Global SearchHookMode

    if (SearchHookMode = "PreCapture") {
        StopSearchHook()
    }
}

ExpirePreCapture() {
    Global SearchHookMode, PreCaptureStartTick

    if (SearchHookMode != "PreCapture") {
        SetTimer(ExpirePreCapture, 0)
        return
    }
    if (WinActive("ahk_group TaskViewGroup") || (A_TickCount - PreCaptureStartTick) >= 350) {
        StopSearchHook()
    }
}

StartTransitionCapture(InitialChar) {
    Global SearchTransitionActive, SearchAborted, SearchBuffer, SearchHookMode, SearchHook

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
    Global SearchHook, SearchHookMode

    SetTimer(ExpirePreCapture, 0)
    ih := SearchHook
    SearchHook := ""
    SearchHookMode := ""
    if (IsObject(ih) && ih.InProgress) {
        ih.Stop()
    }
}

OnSearchHookChar(ih, char) {
    Global SearchHook, SearchHookMode, SearchTransitionActive, SearchAborted, SearchBuffer, LastLWinTap

    if (ih != SearchHook) {
        return
    }

    ; Ignore non-printable control chars and shortcut modifiers (keep AltGr = LCtrl+RAlt working)
    hasShortcutMod := (GetKeyState("LCtrl") && !GetKeyState("RAlt")) || GetKeyState("RCtrl") || GetKeyState("LAlt") || GetKeyState("LWin") || GetKeyState("RWin")
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
    Global SearchHook, SearchHookMode, SearchAborted, SearchBuffer

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
        ; Cancel Pre-Capture on navigation/action keys (never on Shift!)
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
    Global SearchHook, SearchHookMode

    if (ih != SearchHook) {
        return
    }
    SetTimer(ExpirePreCapture, 0)
    if (SearchHookMode = "PreCapture") {
        SearchHookMode := ""
    }
}

TriggerSearch(ThisHotkey) {
    Global SearchTransitionActive, SearchBuffer, LastLWinTap

    LastLWinTap := 0
    if (SearchTransitionActive) {
        SearchBuffer .= ThisHotkey
        return
    }

    StartTransitionCapture(ThisHotkey)
    SetTimer(DoSearchTransition, -1)
}

DoSearchTransition() {
    Global SearchTransitionActive, SearchBuffer, SearchAborted

    try {
        ; 1. Wait briefly if Task View was just triggered via Pre-Capture
        if (!WinActive("ahk_group TaskViewGroup")) {
            WinWaitActive("ahk_group TaskViewGroup", , 0.25)
        }
        if (SearchAborted) {
            return
        }

        ; 2. Close Fenster-Übersicht (Task View)
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

        ; 4. Stage 1 -> Stage 2 handoff (StartMenuExperienceHost -> SearchHost)
        ; Thread-local SetKeyDelay avoids touching clipboard (KDE Connect / GSConnect safe)
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

        ; 5. Flush remaining captured characters while keeping InputHook catching tail input
        Loop 10 {
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
