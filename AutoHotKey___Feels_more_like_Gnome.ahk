#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 🚀 SCRIPT: WorkspacesSwitching-WIN-LINUX.ahk
; 📌 VERSION: v1.6.2 (Final - Bugfix: Start Menu Recursion Flicker)
; ==============================================================================
; 📖 MINI HELP:
; This script enhances Windows 11 to behave more like Linux/Gnome:
; 1. Normalizes workspace switching (Ctrl+Alt+Left/Right -> Ctrl+Win+Left/Right)
;    for tools like Deskflow. Implements a State Machine for fluid continuous
;    switching while holding the modifiers.
; 2. Overrides the Windows (Super) key:
;    - Short tap: Opens Task View (Workspace Overview) instantly
;    - Hold + Key: Acts as a normal modifier
; 3. Task View Search (Gnome-Style):
;    - Typing in Task View instantly redirects to the native Windows Start Menu
;    - Includes keystroke buffering for fast typing without timeouts
; ==============================================================================

Global IsWorkspaceSwitching := false
Global SearchTransitionActive := false
Global SearchBuffer := ""

InstallKeybdHook()
InstallMouseHook()

; ==============================================================================
; TASK VIEW SEARCH HOTKEYS (Gnome-like Typing)
; ==============================================================================
; BUGFIX: Strikt auf explorer.exe begrenzt, damit das Startmenü (SearchHost.exe)
; nicht versehentlich als Task View erkannt wird und in einen Loop rennt!
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
; WORKSPACE SWITCH HOTKEYS (State Machine Method)
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

#HotIf !WinActive("ahk_group DevTools")

^!Left::HandleWorkspaceSwitch("Left")
^!Right::HandleWorkspaceSwitch("Right")

#HotIf ; Reset

HandleWorkspaceSwitch(Direction) {
    Global IsWorkspaceSwitching
    
    if (!IsWorkspaceSwitching) {
        IsWorkspaceSwitching := true
        Send("{Blind}{Alt up}{LWin down}")
        SetTimer(CheckAltRelease, 50)
    }
    Send("{Blind}{" Direction "}")
}

CheckAltRelease() {
    Global IsWorkspaceSwitching
    
    if !GetKeyState("Alt", "P") {
        SetTimer(CheckAltRelease, 0)
        Send("{Blind}{LWin up}")
        IsWorkspaceSwitching := false
    }
}

; ==============================================================================
; WINDOWS KEY MODIFICATION (Active Proxy Method - Tap Only)
; ==============================================================================
*LWin:: {
    Send("{Blind}{LWin down}")
    KeyWait("LWin") ; Wait indefinitely until the physical key is released
    
    if (A_PriorKey = "LWin") {
        Send("{Blind}{Tab}{LWin up}") 
    } else {
        Send("{Blind}{LWin up}")
    }
}

; ==============================================================================
; HELPER FUNCTIONS
; ==============================================================================
TriggerSearch(ThisHotkey) {
    Global SearchTransitionActive, SearchBuffer
    
    if (SearchTransitionActive) {
        SearchBuffer .= ThisHotkey
        return
    }
    
    SearchTransitionActive := true
    SearchBuffer := ThisHotkey
    
    ; 1. Task View abbrechen
    Send("{Esc}")       
    
    ; 2. WICHTIG: Task View wird oft nicht zerstört, verliert nur den Fokus! 
    WinWaitNotActive("ahk_group TaskViewGroup", , 1)
    
    ; 3. Startmenü nativ öffnen
    Send("^{Esc}")        
    
    ; 4. Ein kurzer UI-Sleep ist robuster als das Warten auf flüchtige Exe-Prozesse
    Sleep(150) 
    
    ; 5. Den gesammelten Text abschicken
    Send(SearchBuffer)
    
    ; 6. Lock nach Abschluss etwas flotter freigeben
    SetTimer(ResetSearchState, -300)
}

ResetSearchState() {
    Global SearchTransitionActive := false
    Global SearchBuffer := ""
}