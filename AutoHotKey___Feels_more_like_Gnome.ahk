#Requires AutoHotkey v2.0
#SingleInstance Force

; ==============================================================================
; 🚀 SCRIPT: WorkspacesSwitching-WIN-LINUX.ahk
; 📌 VERSION: v2.1.3 (Final - Double-Tap & Full Deskflow/Gnome Integration)
; ==============================================================================
; 📖 ARCHITECTURE & PHILOSOPHY:
;
; This script bridges the UX gap in a heterogeneous multi-OS environment
; (Arch Linux <-> Windows 11 <-> Debian) operated seamlessly via Deskflow. 
; Because the primary Linux workstations rely on Gnome (Wayland), this script 
; forces Windows 11 to adopt Gnome's core navigation paradigms. The goal is 
; zero friction and unified muscle memory across all operating systems.
;
; 🌟 CORE FEATURES & MECHANICS:
;
; 1. Fluid Workspace Switching (Ctrl+Alt+Left/Right)
;    - Concept: Remaps standard shortcuts to bypass Deskflow's interception 
;      limitations regarding Windows 11's native desktop switching.
;    - Engine: Utilizes a non-blocking State Machine (`IsWorkspaceSwitching`) 
;      with a 50ms polling loop. This guarantees clean modifier release 
;      (Alt/Win) and prevents the notorious "stuck key" bug when transitioning 
;      input focus across machine boundaries.
;
; 2. The "Gnome Start" Emulation (Super Key Interception)
;    - Concept: Replicates Gnome's "Activities" overview. Windows 11 strictly 
;      separates its Task View from the Start Menu search, breaking the fluid
;      "Super -> Type" workflow. This script fuses them back together.
;    - Behavior: 
;      * Single Tap [Super]: Opens Task View immediately.
;      * Typing [A-Z, 0-9] in Task View: Instantly intercepts the input, kills 
;        the Task View, triggers the native Start Menu, and dumps all typed 
;        characters from a high-speed buffer into the search field.
;    - Technical Detail: To avoid recursive infinite loops, the interceptor 
;      is strictly bound to `explorer.exe`, differentiating the Task View from 
;      the visually identical XAML containers used by `SearchHost.exe`.
;
; 3. Direct Start Menu Fallback (Double-Tap Super)
;    - Concept: A rapid double-tap (within 400ms) on the Super key bypasses 
;      the Task View entirely, forcing the native Windows Start Menu to open 
;      for immediate, non-buffered access.
;
; 4. Hardcoded DevTool Exceptions
;    - Concept: Ensures that critical applications like IDEs (VS Code, JetBrains), 
;      VMs (VMware, VirtualBox), and RDP sessions retain full capture of native 
;      keystrokes, disabling workspace hooks when these windows are active.
; ==============================================================================

Global IsWorkspaceSwitching := false
Global SearchTransitionActive := false
Global SearchBuffer := ""
Global LastLWinPress := 0

InstallKeybdHook()
InstallMouseHook()

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
; WINDOWS KEY MODIFICATION (Tap / Double-Tap / Proxy)
; ==============================================================================
*LWin:: {
    Global LastLWinPress
    TimeSinceLastPress := A_TickCount - LastLWinPress
    LastLWinPress := A_TickCount

    Send("{Blind}{LWin down}")
    KeyWait("LWin") ; Wait indefinitely until the physical key is released
    
    if (A_PriorKey = "LWin") {
        if (TimeSinceLastPress > 0 and TimeSinceLastPress < 400) {
            ; --- DOUBLE TAP: Direct Start Menu ---
            Send("{Blind}{LWin up}")
            Send("{Esc}")       ; Gracefully close the Task View from the first tap
            Sleep(50)           ; Micro-delay for UI state flush
            Send("^{Esc}")      ; Force native Start Menu open
        } else {
            ; --- SINGLE TAP: Open Task View ---
            Send("{Blind}{Tab}{LWin up}") 
        }
    } else {
        ; --- MODIFIER USAGE (e.g., Win+E) ---
        Send("{Blind}{LWin up}")
    }
}

; ==============================================================================
; HELPER FUNCTIONS (Search Interception & Buffering)
; ==============================================================================
TriggerSearch(ThisHotkey) {
    Global SearchTransitionActive, SearchBuffer
    
    if (SearchTransitionActive) {
        SearchBuffer .= ThisHotkey
        return
    }
    
    SearchTransitionActive := true
    SearchBuffer := ThisHotkey
    
    ; 1. Kill Task View
    Send("{Esc}")       
    
    ; 2. Wait until Task View loses focus (WinWaitNotActive avoids destroying timeout)
    WinWaitNotActive("ahk_group TaskViewGroup", , 1)
    
    ; 3. Open native Start Menu
    Send("^{Esc}")        
    
    ; 4. UI-Sleep for search host allocation
    Sleep(150) 
    
    ; 5. Flush buffered text
    Send(SearchBuffer)
    
    ; 6. Release lock quickly
    SetTimer(ResetSearchState, -300)
}

ResetSearchState() {
    Global SearchTransitionActive := false
    Global SearchBuffer := ""
}