# gnome-hotkeys-for-windows

Bring GNOME's out-of-the-box keyboard navigation, virtual desktop switching, and instant type-to-search workflow to Windows 11.

![Version](https://img.shields.io/badge/Version-v2.6.2-blue)
![OS](https://img.shields.io/badge/OS-Windows%2011-0078D4?logo=windows11)
![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0.23%2B-334455)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## Why This Script Exists

If you regularly switch between GNOME on Linux and Windows—whether by dual-booting or working across a desktop and laptop side by side—diverging core hotkeys break your muscle memory constantly. Pressing `Ctrl+Alt+Left/Right` to hop between workspaces or tapping `Win` and typing immediately to launch an app does nothing (or the wrong thing) on Windows.

`gnome-hotkeys-for-windows` is a lightweight, zero-dependency AutoHotkey v2 script that aligns Windows with GNOME's default keyboard workflow.

## Table of Contents

- [Anti-Cheat Safety](#anti-cheat-safety)
- [Install](#install)
- [Hotkeys](#hotkeys)
- [How It Works](#how-it-works)
  - [How the `Win` Key Works](#how-the-win-key-works)
  - [Virtual Desktop Switching](#virtual-desktop-switching)
- [Hotkeys Which Are Identical in Windows & GNOME](#hotkeys-which-are-identical-in-windows--gnome)
- [5 Windows Hotkeys Worth Knowing](#5-windows-hotkeys-worth-knowing)
- [Automatic VM Exclusions](#automatic-vm-exclusions)
- [Anti-Cheat Details](#anti-cheat-details)
- [Settings](#settings)
- [TODO](#todo)
- [Changelog](#changelog)
- [License](#license)

---

## Anti-Cheat Safety

> [!WARNING]
> **Automatic silent exit when gaming is detected:** For strict anti-cheats and zero-tolerance competitive titles, the mere presence of a running AutoHotkey process in your process list—regardless of what the script does—can be enough to block launching, kick you, or trigger a permanent ban. As soon as a monitored gaming launcher or anti-cheat process starts, this script releases any held modifier and **exits silently** (`ExitApp(0)`, no dialog) so no AutoHotkey process remains running.  
> See [Anti-Cheat Details](#anti-cheat-details) below for the full process list, Riot Vanguard notes, Steam autostart tip, and how to customize `AntiCheatGuards`.

---

## Install

### Requirements

- **OS:** Windows 11 *(most features should also work on Windows 10, though currently untested)*
- **AutoHotkey:** **v2.0.23 or newer** (minimum) — download from [autohotkey.com](https://www.autohotkey.com/)

### Quick Start

1. Install the latest **AutoHotkey v2** from [autohotkey.com](https://www.autohotkey.com/).
2. Download `gnome-hotkeys-for-windows.ahk`.
3. Double-click `gnome-hotkeys-for-windows.ahk` to start it.

While running, each AutoHotkey script shows a **green `H` icon** in your Windows **system tray** *(notification area, bottom-right near the clock)*. Right-clicking that icon lets you **Reload**, **Edit**, **Pause/Suspend** *(the icon turns red while paused)*, or **Exit** the script at any time.

### Optional: Run Automatically at Startup

1. Press `Win+R`, type `shell:startup`, and press `Enter` — this opens Windows' Startup folder.
2. In a second File Explorer window, right-click `gnome-hotkeys-for-windows.ahk` → **Create shortcut**, then drag or move that shortcut into the Startup folder.

---

## Hotkeys

| Hotkey / Trigger | Action |
|---|---|
| `Win` *(single tap)* | Open Task View (window & virtual desktop overview) |
| `Win` or `Esc` *(while Task View is open)* | Close Task View |
| Start typing *(while Task View is open, or even while it is still opening)* | Seamless GNOME-style search in the Windows Start Menu |
| `Win` *(quick double-tap < 400 ms)* | Open the native Windows Start Menu directly (skips overview) |
| `Win` + `<key>` *(hold)* | Normal Windows hotkeys (`Win+E`, `Win+L`, `Win+Shift+S`, etc.) |
| `Ctrl` + `Alt` + `Left` / `Right` | Switch to the previous / next virtual desktop (hold to repeat) |
| `Left Ctrl` + `Left Alt` + `1`..`7` | Jump directly to virtual desktop 1–7 *(hold `Left Ctrl` + `Left Alt` to hop across multiple desktops; see [Virtual Desktop Switching](#virtual-desktop-switching))* |
| `Ctrl` + `Alt` + `T` | Launch Windows Terminal (`wt.exe`; falls back to `powershell.exe`) |

---

## How It Works

### How the `Win` Key Works

- **How GNOME does it:** Tapping `Win` *(called `Super` on Linux)* opens the Activities Overview. If you don't type, you stay in the overview until you press `Win` or `Esc` again. If you start typing—either right after tapping `Win` or later while the overview is open—GNOME immediately filters matching apps and files.
- **How Windows 11 does it out of the box:** Task View (`Win+Tab`) and Start Menu Search (`Ctrl+Esc`) are completely separate; typing while Task View is open does nothing.
- **How this script bridges the gap:**
  - **Single-tap `Win`** opens Windows Task View; tapping **`Win`** again or pressing **`Esc`** closes it.
  - **Typing while Task View is open—or even while it is still opening—** is captured seamlessly by a non-blocking `InputHook` (including a short pre-capture window right after tapping `Win`). The script closes Task View, opens Start Menu Search, waits for `SearchHost.exe` to focus, and types your entire buffered query without dropping characters and without touching your clipboard. Press `Backspace` to fix typos mid-transition or `Esc` to cancel.
  - **Quick Double-Tap `Win` (within 400 ms)** opens the classic Windows Start Menu directly—useful whenever you want pinned apps or the power menu without typing.
  - **Holding `Win` with another key** passes through normally for all native Windows hotkeys (`Win+E`, `Win+L`, `Win+Shift+S`, etc.).

### Virtual Desktop Switching

- **Relative (`Ctrl+Alt+Left` / `Right`):** Maps cleanly to Windows' native `Ctrl+Win+Left/Right` while keeping modifier state clean (no stuck `Alt` or `Win` keys, no accidental menu-bar focus).
- **Direct (`Left Ctrl+Left Alt+1..7`):** Switches directly to your chosen virtual desktop (1–7) by stepping sequentially until it reaches your target. You can keep `Left Ctrl` + `Left Alt` held down and press additional numbers in sequence—even mid-jump—to redirect immediately to another desktop without overshooting.
  - **Why can't it jump instantaneously?** Unlike GNOME, Windows 11 provides neither native direct-jump hotkeys nor a public Virtual Desktop API, and does not allow remapping built-in workspace hotkeys. Because of these Windows limitations, stepping across desktops one by one while waiting for Windows to confirm each transition is the only reliable approach without fragile system hacks. Since Windows animates each transition, jumping across several desktops (e.g., 5 → 1) takes a brief moment.

> [!TIP]
> **Faster multi-desktop jumps (`Left Ctrl+Left Alt+1..7`):** Windows 11 plays a sliding transition animation on every workspace step. Turning off **Settings → Accessibility → Visual effects → Animation effects** makes multi-step jumps nearly instantaneous—the script automatically adapts to the faster transition speed.

- **Why only Left `Ctrl` and Left `Alt` (and not Right)?** Windows supports over 200 international keyboard layouts. To fit extra characters (such as `ä`, `ö`, `ü`, `{`, or `@` on German and other European layouts), many layouts treat the **Right** `Alt` key differently—commonly labeled **`AltGr`**, which Windows sends as `Left Ctrl + Right Alt`. To keep behavior identical across all keyboard layouts without interfering with `AltGr`, direct workspace jumps intentionally use only **Left** `Ctrl` and **Left** `Alt`, which behave identically on every keyboard layout.

---

## Hotkeys Which Are Identical in Windows & GNOME

Windows and GNOME already share several core navigation hotkeys out of the box—no remapping needed:

| Hotkey | Action (Windows & GNOME) |
|---|---|
| `Win` + `L` | Lock screen |
| `Win` + `Left` / `Right` | Snap / tile active window to left or right half |
| `Win` + `Up` / `Down` | Maximize / restore (or minimize) active window |
| `Win` + `D` | Show desktop |
| `Alt` + `Tab` | Switch between open applications |
| `Alt` + `F4` | Close the active window |

---

## 5 Windows Hotkeys Worth Knowing

Because holding `Win` still acts as a normal Windows modifier, all native `Win+<Key>` hotkeys keep working:

| Hotkey | Action | Available Since |
|---|---|---|
| `Win` + `E` | Open File Explorer | Windows 95 |
| `Win` + `V` | Open Clipboard History | Windows 10 (1809) |
| `Win` + `Shift` + `S` | Open Snipping Tool (region screenshot) | Windows 10 (1703) |
| `Win` + `.` *(or `Win` + `;`)* | Open Emoji, GIF & Symbol picker | Windows 10 (1709) |
| `Win` + `X` | Opens a menu with shortcuts useful for Power Users & Admins | Windows 8 |

For a complete, regularly updated list of every Windows hotkey across Windows 10 and Windows 11, see Microsoft's official reference:  
**[Keyboard shortcuts in Windows — Microsoft Support](https://support.microsoft.com/en-us/windows/keyboard-shortcuts-in-windows-dcc61a57-8ff0-cffe-9796-cb9706c75eec)**

---

## Automatic VM Exclusions

Whenever a fullscreen VM or remote desktop viewer is active, **all our hotkey processing is paused until you switch to another window that is not on the `ExcludedApps` list**, so the guest OS receives every keystroke natively.

The default `ExcludedApps` list at the top of `gnome-hotkeys-for-windows.ahk` includes:

- `vmware.exe` — VMware Workstation / Player
- `VirtualBoxVM.exe` — Oracle VirtualBox
- `vmconnect.exe` — Windows Hyper-V VM Connection
- `qemu-system-x86_64.exe` — QEMU (64-bit)
- `remote-viewer.exe` — SPICE / virt-viewer (Proxmox / KVM)
- `mstsc.exe` — Windows Remote Desktop *(comment this line out if you use RDP in a small window and want local host hotkeys active)*

---

## Anti-Cheat Details

### How Anti-Cheat Safety Works

Depending on the game and anti-cheat configuration, **the mere existence of a running AutoHotkey process (`AutoHotkey64.exe` / `AutoHotkey32.exe`) in the process list**—regardless of whether your script ever touches the game window or intercepts gameplay input—can be enough to block launching, kick you, or in documented zero-tolerance titles (e.g., competitive shooters using strict process blacklists) trigger a permanent ban. Merely suspending a script keeps AutoHotkey and its low-level hook in memory.

Therefore, our Anti-Cheat Safety checks `AntiCheatGuards` **immediately on startup** (before installing its keyboard hook) and then passively **once per second** via `ProcessExist()` (standard OS process enumeration—never opens a handle to any game or anti-cheat process). As soon as any listed launcher or anti-cheat process appears, the script releases any held modifier and terminates silently via `ExitApp(0)`. Monitoring launchers in addition to anti-cheat engines ensures AutoHotkey is already gone seconds before a game's anti-cheat initializes.

*(After closing your game/launcher, simply restart `gnome-hotkeys-for-windows.ahk`.)*

### Default `AntiCheatGuards` List

```ahk
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
```

### Important Notes & Tips

- **Riot Vanguard (`vgc.exe` / `vgtray.exe`):** Vanguard's kernel driver loads at Windows boot, so `vgc.exe` and `vgtray.exe` are **intentionally not** in `AntiCheatGuards` (otherwise the script could never run on desktop). Simply having Vanguard installed at boot does not ban you for desktop AutoHotkey use; `RiotClientServices.exe` is monitored instead so our Anti-Cheat Safety exits the script as soon as Riot Client opens. If you rarely play Riot games and prefer Vanguard completely off, right-click the Vanguard system tray icon → **Exit Vanguard** *(note: Windows must be rebooted before playing Valorant or League of Legends again)*.
- **Steam / Launcher Autostart:** If Steam launches automatically when Windows boots, our Anti-Cheat Safety will immediately exit this script on login. To disable Steam autostart: open **Steam → Settings → Interface** and turn off **"Run Steam when my computer starts"**. *(Alternatively, if you want Steam always running in the background, you can comment out `"steam.exe"` in `AntiCheatGuards`—just keep in mind that our Anti-Cheat Safety will then rely on the anti-cheat process starting, which leaves a narrower timing margin.)*
- **More detailed info on Anti-Cheat Protection:**
  - Here you find very detailed info on each anti-cheat system in existence: [PCGamingWiki — Anti-cheat middleware](https://www.pcgamingwiki.com/wiki/Anti-cheat_middleware)
  - Here you can search for your game of interest to see which anti-cheat it uses: [AreWeAntiCheatYet](https://areweanticheatyet.com/)

---

## Settings

All settings are at the top of `gnome-hotkeys-for-windows.ahk`:

| Variable | Purpose |
|---|---|
| `AntiCheatGuards` | Launchers & anti-cheat processes that trigger an immediate silent exit (`ExitApp(0)`). |
| `ExcludedApps` | VM / remote desktop executables where all hotkey processing is paused. |
| `WORKSPACE_JUMP_STEP_TIMEOUT_MS` | Max wait (ms) for Windows to confirm each desktop step before retrying once during `Left Ctrl+Left Alt+1..7` jumps (default: `500`). |

---

## TODO

Planned improvements for upcoming releases (`v2.7.0` / `v2.8.0`):

- **Close all other AutoHotkey instances on anti-cheat detection (option, enabled by default):** When Anti-Cheat Safety triggers, also terminate other running `AutoHotkey64.exe` / `AutoHotkey32.exe` processes in case other user scripts do not implement their own anti-cheat check.
- **Graphical Settings dialog (GUI + persistent `.ini`):** Edit `AntiCheatGuards`, `ExcludedApps`, and `WORKSPACE_JUMP_STEP_TIMEOUT_MS` directly via a native GUI without modifying source code, accessible via hotkey and the system tray right-click menu.
- **Offline-capable Help viewer:** Download and cache the version-matched `README.md` from GitHub on first use so documentation is available offline via hotkey and the system tray right-click menu (with automatic version refresh on script updates).

---

## Changelog

### v2.6.2 (2026-11-24)
- Rewrote direct workspace jumping (`Left Ctrl+Left Alt+1..7`) as a closed-loop state machine waiting for Windows Registry confirmation on each step (eliminates overshoot and desync on rapid/repeated presses and allows instant mid-jump redirection).
- Added continuous direct workspace hopping: keep `Left Ctrl` + `Left Alt` held and press multiple numbers in sequence via dynamically toggled `<^1..7` continuation hotkeys and a unified `OnWorkspaceModifierUp()` handler.
- Eliminated accidental `Win+Left/Right` window snapping during desktop jumps by holding synthetic `RCtrl` across each step.
- Replaced `WORKSPACE_JUMP_STEP_DELAY_MS` with `WORKSPACE_JUMP_STEP_TIMEOUT_MS` (`500` ms default).

### v2.6.1 (2026-11-09)
- Overhauled `README.md` for clarity and consistent terminology (`Hotkeys`, `Win`, `Anti-Cheat Safety`, `Settings`), clarified process-blacklist anti-cheat risks, simplified the `Virtual Desktop Switching` explanation, added a `TODO` roadmap, and refined hotkey/install instructions.
- Standardized concise function-level documentation comments throughout `gnome-hotkeys-for-windows.ahk`.

### v2.6.0 (2026-11-02)
- Renamed script to `gnome-hotkeys-for-windows.ahk`, extracted full documentation into `README.md`, added MIT `LICENSE`, and standardized all comments/identifiers to English.
- Set minimum requirement to AutoHotkey `v2.0.23` (`#Requires AutoHotkey v2.0.23`).
- Added `Ctrl+Alt+T` hotkey to launch Windows Terminal (`wt.exe`; falls back to `powershell.exe`).
- Renamed `AntiCheatGuardExes` to `AntiCheatGuards` and expanded default coverage to major launchers and anti-cheat engines (Steam, Epic Games, Battle.net, EA App, Ubisoft Connect, Riot Client, RSI Launcher/Star Citizen, FACEIT, EAC, BattlEye, EA AntiCheat, GameGuard).
- Replaced `DevTools` exclusions with a top-level configurable `ExcludedApps` VM/RDP list (`vmware.exe`, `VirtualBoxVM.exe`, `vmconnect.exe`, `qemu-system-x86_64.exe`, `remote-viewer.exe`, `mstsc.exe`) and extended it to pause all custom hotkey processing—including `*LWin` (with dynamic `*LWin up`) and `Ctrl+Alt+T`—inside excluded windows.

### v2.5.1 (2026-10-26)
- Fixed dropped characters when typing rapidly after pressing `Win` using a continuous `InputHook("B I1 T2.5")` with Pre-Capture right after opening Task View, seamless upgrade to Transition capture, `Backspace`/`Esc` support, German umlaut/ß hotkeys (`ä`, `ö`, `ü`, `ß`), and a 2-stage Start Menu (`StartMenuExperienceHost.exe` → `SearchHost.exe`) flush with thread-local `SetKeyDelay(10, 5)` and zero clipboard usage.

### v2.5.0 (2026-10-19)
- Added Anti-Cheat Safety checking on startup (before hook installation) and every 1000 ms via passive `ProcessExist()`.
- Added direct virtual desktop switching (`Left Ctrl+Left Alt+1..7`) via pure Windows Registry lookup (`VirtualDesktopIDs` / `CurrentVirtualDesktop`).
- Narrowed `TaskViewGroup` to Windows 11 `XamlExplorerHostIslandWindow` only.
- Switched workspace modifier-release hotkeys (`~*LAlt/RAlt/LCtrl/RCtrl up`) to dynamic `On`/`Off` toggling and lowered priority to `AboveNormal`.

### v2.2.0 (2026-10-12)
- Switched to `SendMode("Event")` + `SetKeyDelay(-1, -1)` and `A_MenuMaskKey := "vkE8"` to eliminate `SendInput` hook churn/fallback delays and phantom `Ctrl` masking.
- Removed unnecessary `InstallMouseHook()`.
- Replaced blocking `KeyWait("LWin")` with non-blocking `*LWin` / `*LWin up` state tracking, replaced `#HotIf` with hook-evaluated `HotIfWinNotActive`, and switched workspace release fallback to logical `GetKeyState("Ctrl")`.

### v2.1.3 (2026-05-18)
- Added quick double-tap `Win` (< 400 ms) fallback to open the native Start Menu directly.

### v1.6.2 (2026-05-17)
- Initial release with `Ctrl+Alt+Left/Right` workspace switching, single-tap `Win` Task View proxy, and Task View typing redirect bound strictly to `explorer.exe`.

---

## License

Licensed under the [MIT License](LICENSE) — Copyright (c) 2026 Sven Dawitz.
