# Elipsis Shell — Agent Guide

## Run

```sh
qs # launch (no build step)
```

Must clone into `~/.config/quickshell/`. No build system. No tests, linter, or typechecker. The repo root is what Quickshell loads as its config dir.

## Entrypoint

[`.config/quickshell/shell.qml`](.config/quickshell/shell.qml) — a single `ShellRoot` component (~126 lines). All backend state lives in `services/` singletons. `shell.qml` only contains: IPC handlers (delegating to services), the `PwObjectTracker` for Pipewire, the `Variants` tree mounting UI components, and the `NotificationPopup` toast bridge.

## Layout — actual

```
.config/quickshell/
├── shell.qml                              # ShellRoot — composition + IPC delegation only
└── services/                              # all backend singletons (pragma Singleton + qmldir)
    ├── qmldir                             # declares all singleton types at 1.0
    ├── ConfigStore.qml                    # config persistence, pinnedApps, toggleData
    ├── Dock.qml                          # dock ListModel + refreshDock()
    ├── Network.qml                       # wifi/ethernet + nmcli polling + scan
    ├── Bluetooth.qml                      # BT adapter + bluetoothctl polling
    ├── Battery.qml                       # UPower displayDevice bindings
    ├── Brightness.qml                    # backlight detection + read/write + kbd/dark-mode
    ├── Wallpapers.qml                    # awww query + blur pipeline + appearance state
    ├── Notifications.qml                  # NotificationServer wrapper + dndActive
    ├── PowerProfiles.qml                 # net.hadess.PowerProfiles D-Bus
    ├── Caffeine.qml                      # hypridle pause/resume
    ├── Recorder.qml                       # gpu-screen-recorder lifecycle
    ├── SystemActions.qml                 # power/lock/audio/settings/launch/killApp
    ├── UIState.qml                       # panel/drawer/switcher flags + workspace tracking
    ├── Lock.qml                          # WlSessionLock + lock/unlock
    └── Icons.qml                         # breeze-dark icon lookup table
└── components/                           # all UI (flat + 2 nested subdirs)
    ├── MaterialSurface.qml                # shared theming primitive
    ├── StackCard.qml                    # container with grouped cards
    ├── StatusCluster.qml                 # status bar pill cluster
    ├── Lockscreen.qml                    # WlSessionLockSurface
    ├── QuickSettings.qml                 # control center panel
    ├── StatusBar.qml                     # swipe-down → opens QuickSettings
    ├── BackgroundBar.qml                 # bottom 24px reserved strip + dim layer
    ├── BottomBar.qml                     # dock visuals popup
    ├── VolumeOSD.qml                     # Pipewire volume overlay
    ├── PowerMenu.qml                     # logout/reboot/suspend dialog
    ├── NotificationPopup.qml              # toast (globalToast id in shell.qml)
    ├── TaskManager.qml                   # window switcher panel
    ├── AppDrawer.qml                    # app launcher drawer
    ├── EditOverlay.qml                  # control-center edit-mode UI
    ├── ExpandedHeader.qml               # header for expanded toggle views
    ├── AppContextMenu.qml               # right-click menu
    ├── toggles/                        # 12 control-center toggle widgets
    │   ├── BluetoothToggle.qml
    │   ├── BrightnessSlider.qml
    │   ├── CaffeineToggle.qml
    │   ├── DndToggle.qml
    │   ├── LockToggle.qml
    │   ├── MediaWidget.qml
    │   ├── NetworkToggle.qml
    │   ├── PowerProfileToggle.qml
    │   ├── PowerToggle.qml
    │   ├── ScreenRecordToggle.qml
    │   ├── SettingsToggle.qml
    │   └── VolumeSlider.qml
    └── reusables/                      # local qmldir
        ├── TouchComboBox.qml
        ├── ToggleListItem.qml
        ├── ContextMenu.qml
        ├── BatteryIcon.qml
        └── qmldir

config/config.json                        # gitignored user state
```

## Services API

All services are singletons declared in `services/qmldir`. Consumers add `import "services"` and access properties/methods directly: `ConfigStore.pinnedApps`, `Network.wifiConnected`, `Wallpapers.accentColor`, etc.

| Service | Key properties | Key methods |
|---------|---------------|-------------|
| `Icons` | — | `icon(name)` → `"file://..."` |
| `ConfigStore` | `pinnedApps`, `toggleData`, `controlCenterLayout`, `mediaPlayerId`, `configLoadComplete` | `saveConfig()`, `setToggleSetting()`, `togglePin()`, `movePinnedApp()` |
| `Lock` | `isLocked` | `lock()`, `unlock()`, `toggle()` |
| `UIState` | `panelOpen`, `powerMenuOpen`, `appDrawerOpen`, `switcherOpen`, `barState`, `hasWindowsOnCurrentWs`, `hasSingleTiledWindow` | `closeOtherOverlays(except)`, `openContextMenuAtCursor()`, `closeContextMenu()` |
| `Dock` | `dockAppsModel` (ListModel alias) | `refreshDock()` |
| `Battery` | `batteryPct`, `batteryStatus` | — |
| `Brightness` | `brightnessValue`, `kbdBacklightValue`, `darkModeActive`, `nightLightActive`, `autoBrightnessActive` | `setBrightness(pct)`, `setKbdBacklight(pct)`, `setDarkMode(bool)` |
| `Network` | `wifiEnabled`, `wifiConnected`, `wifiDevice`, `ethernetConnected`, `networkName`, `networkSignalLevel`, `isScanningNetwork` | `toggleWifi()`, `refreshNetwork()`, `disconnectEthernet()`, `connectEthernet()` |
| `Bluetooth` | `bluetoothEnabled`, `bluetoothConnected`, `bluetoothDeviceName`, `connectedBluetoothDevices`, `bluetoothScanningManual` | `toggleBluetooth()`, `startBluetoothDiscovery()` |
| `Wallpapers` | `wallpaperPath`, `blurredWallpaperPath`, `blurVersion`, `blurEnabled`, `staticBlurEnabled`, `usePrecomputedBlur`, `materialTheme`, `accentColor` | `setMaterial()`, `setBlurEnabled()`, `setPrecomputedBlur()` |
| `Notifications` | `notificationList`, `dndActive` | `dismiss()`, `dismissByApp()`, `clearAll()`, `setDnd(bool)` |
| `PowerProfiles` | `powerProfile` | `setPowerProfile(name)` |
| `Caffeine` | `caffeineActive` | `setCaffeine(bool)` |
| `Recorder` | `isScreenRecording` | `toggleScreenRecording(...)` |
| `SystemActions` | — | `powerOff()`, `reboot()`, `suspend()`, `lockScreen()`, `setDefaultAudio(nodeId)`, `openSettings()`, `launchEntry(entry)`, `launchExec(cmd)`, `killApp(entryId)` |

## IPC

Five `IpcHandler` blocks in `shell.qml` (the canonical IPC source). Each delegates to a service:

| Target | Source line | Functions | Delegates to |
|--------|-------------|-----------|-------------|
| `lock` | `shell.qml:23` | `toggle`, `lock`, `unlock` | `Lock` |
| `appearance` | `shell.qml:33` | `setPrecomputedBlur(bool)`, `setBlurEnabled(bool)`, `setMaterial(string)` | `Wallpapers` |
| `power` | `shell.qml:41` | `show`, `hide`, `toggle` | `UIState` |
| `quicksettings` | `shell.qml:51` | `show`, `hide`, `toggle` | `UIState` |
| `task_manager` | `shell.qml:61` | `toggle`, `open`, `close` | `UIState` |

## Config schema

`config/config.json` is the single source of truth. Loaded by `ConfigStore.loadConfigProc` at startup; rewritten by `ConfigStore.saveConfig()` as a full-rewrite via `sh -c 'echo "$1" > "$2.tmp" && mv "$2.tmp" "$2"'`.

```jsonc
{
  "pinnedApps": ["zen", "helium", "dev.zed.zed"],
  "toggleData": {
    "DndToggle": { "active": false },
    "ScreenRecordToggle": { "audio": 0, "fps": 0, "encoder": 0, "res": 0, "bitrate": 0 }
  },
  "appearance": {
    "materialTheme": "Acrylic",
    "staticBlurEnabled": true,
    "blurEnabled": true,
    "accentColor": "#3366ff",
    "wallpaperPath": ""
  },
  "layout": [
    { "source": "toggles/NetworkToggle.qml", "colSpan": 2, "rowSpan": 1 },
    { "source": "toggles/BluetoothToggle.qml", "colSpan": 2, "rowSpan": 1 }
  ],
  "mediaPlayerId": ""
}
```

A `FileView` watcher in `ConfigStore.qml` re-runs `loadConfigProc` when the file changes on disk.

## Key conventions

- **Services** are `pragma Singleton` QML singletons declared in `services/qmldir`. Always access via `Service.property` / `Service.method()` — never store a local reference to a service. Circular service dependencies are avoided by design.

- **Config persistence** lives in `ConfigStore`. Adding a new config field means: (1) read it in `ConfigStore.loadConfigProc.onStreamFinished`, (2) write it in `ConfigStore.saveConfig()`, (3) declare a `property` on `ConfigStore`. Auto-save for appearance fields is wired by `Connections { target: Wallpapers }` in `Wallpapers.qml` calling `ConfigStore.saveAppearance()`.

- **Toggles** live in `components/toggles/`. Any `.qml` there with `isControlWidget: true` becomes a candidate widget. Simple toggles expose `isSimpleToggle: true`, `toggleName`, `iconSource`, `isActive`, `activeColor`, `signal toggled()`. Complex toggles (`BrightnessSlider`, `VolumeSlider`, `MediaWidget`) skip `isSimpleToggle` and render their own chrome. Hybrids (`PowerProfileToggle`, `ScreenRecordToggle`) declare **both** `isSimpleToggle` and `hasExpandedView`.

- **Layout** is an ordered array in `config.config.json` under the `layout` key. Each entry: `{ source: string, colSpan: int, rowSpan: int }`. The **default** layout lives at `QuickSettings.qml` (`property var defaultLayout`). The `widgetLoader` `Loader` (id `widgetLoader`) mounts each entry by `source` relative path.

- **Theming** is centralized in `MaterialSurface.qml`. Three materials: `Solid` (dark opaque), `Acrylic` (white 25%), `Frosted Glass` (white 10% + gradient border). Set globally via `Wallpapers.materialTheme`. Material surfaces expose `fgColor` and `iconColor`. **Always bind child text/icons to `bgSurface.fgColor` / `bgSurface.iconColor`**, never hardcode `"white"`.

- **Gestures**: `BottomBar.qml` handles dock states + task switcher (swipe up) + workspace switch (horizontal). `StatusBar.qml` handles swipe-down to open QuickSettings. The bottom strip is two stacked `PanelWindow`s per screen: `BackgroundBar.qml` owns the reserved 24 px strip + dim layer; `BottomBar` floats above it.

- **Animations** use `Easing.OutExpo` (200-500 ms) or `Easing.OutBack` for scale bounces. `MaterialSurface` uses 200 ms `ColorAnimation` on background color changes.

- **IDs consumers need**: `controlPanel` is the QuickSettings grid container — its `editMode` bool gates edit-mode interactions.

## Commands used (Hyprland/Linux)

| What | How |
|---|---|
| Network | `nmcli` (connect, scan, radio toggle) |
| Bluetooth | `bluetoothctl` (power, scan) |
| Power profiles | `busctl` on `net.hadess.PowerProfiles` |
| Brightness | `cat /sys/class/backlight/...` for read; `busctl SetBrightness` on `org.freedesktop.login1` (in `services/Brightness.qml`) |
| Screen record | `gpu-screen-recorder` (in `services/Recorder.qml`) |
| Caffeine | `pkill -STOP/-CONT hypridle` (in `services/Caffeine.qml`) |
| Wallpaper query | `awww query` → blurs via `magick` (in `services/Wallpapers.qml`) |
| Power actions | `systemctl poweroff\|reboot\|suspend`, `loginctl lock-session` (in `services/SystemActions.qml`) |
| Default audio device | `wpctl set-default` (in `services/SystemActions.qml`) |

## Gotchas

- `config/config.json` is **gitignored**. Agent must not commit it.

- **`shell.qml` has no state** — all backend state lives in `services/` singletons. `shell.qml` is pure composition. Do not add new `property` declarations or `Process` components to `shell.qml`.

- **PR authorship**: Do **not** add yourself (the agent) as a `Co-authored-by:` trailer to commits or PRs on this repo. Keep commits under the user's own authorship. If you're using a tool that auto-adds a co-author trailer, strip it before committing.

- **Notifications toast bridge**: `shell.qml` owns `NotificationPopup { id: globalToast }` and a `Connections { target: Notifications }` that calls `globalToast.show(item)` when `Notifications.notificationReceived` fires. The `NotificationPopup` itself reads from `Notifications.notificationList` for its popup view.

- **`MaterialSurface` exposes `fgColor` and `iconColor`** — hardcoding `"white"` in components breaks Frosted-Glass active-state inversion.

- **Dock model** is `Dock.dockAppsModel` — a `ListModel`. Use `get()`, `setProperty()`, `insert()`, `remove()`, `move()`. Mutations live in `Dock.refreshDock()`.

- **`icon(name)`** is now `Icons.icon(name)` (from `services/Icons.qml`). Add new entries to the lookup table there.

- **Tray icons**: `SystemTray.items` must keep `visible: true` for `image://icon/` providers to serve data.

- **`qmldir`**: `services/qmldir` declares all 15 singletons. `components/reusables/qmldir` declares `TouchComboBox`, `ToggleListItem`, `ContextMenu`, `BatteryIcon`.

- **Stub toggles**: `LockToggle.qml` and `SettingsToggle.qml` only `console.log` in `onToggled`; they are not wired to anything.

- **Cross-id coupling**: `VolumeSlider`, `BrightnessSlider`, `MediaWidget` reference `controlPanel.editMode` (the QuickSettings grid container id) and only work when mounted inside QuickSettings.

- **Hardcoded emoji glyphs**: `BottomBar.qml` and `AppDrawer.qml` have emoji glyphs. Replace with `Icons.icon(...)` lookups when the keys are added.

- **Leftover**: `VolumeOSD.qml.bak` sits next to the active file in `components/`.

## ExpandedUI morph — phase history

The control-center "expandedUI" morph (open → full-screen → close) lives entirely in `QuickSettings.qml` under the `expandedOverlay`/`widgetBg` blocks.

| Phase | What it established | What it left behind |
|---|---|---|
| **F** | The geometry-first close order. | `close()` body structure. |
| **G2** | The radius-must-be-broken-BEFORE-geometry rule for `open()`. | `open()` writes `sourceItem.radius = 16` before geometry block. |
| **G3** | `close()` drives close corner-rounding with an explicit `NumberAnimation` via `numberAnimationComponent.createObject()`. A static fallback write below stays. | The `radiusAnim.to = X` literal. |
| **H** | Per-toggle isolation via captured `del` at open time. | `sourceRadius > 0 ? sourceRadius : 24` literal fallback. |
| **I** | `morphCompleteTimer` binding restore uses LIVE cell-bound formula from captured `del`. | Did not update `radiusAnim.to` in `close()` — regression for Phase K. |
| **K** | Compute `naturalRadius` from `del` and use for BOTH `radiusAnim.to` and `sourceItem.radius`. No end-of-morph snap. | Current state. |

### Bug class to watch for

**Never write a literal numeric value as an end-radius in `close()` or any other morph path that gets restored by a binding 400 ms later.** The invariant: every end-radius must be derived from `del` using `(del.colSpan >= 2 && del.rowSpan >= 2) ? 16 : Math.min(del.width, del.height) / 2`.

### Files that own the morph

- `QuickSettings.qml` — `expandedOverlay`, `widgetBg` delegate, `open()`, `close()`, `morphCompleteTimer`, `numberAnimationComponent`.
- Phase I's `delegateItem` `colSpan`/`rowSpan` declarations are at `QuickSettings.qml:1523`.

## Drift delta (this file vs the repo, 2026-09-08)

The services extraction completed 2026-09-08. The following old entries are now stale:

| AGENTS.md previously said | Reality |
|---|---|
| `shell.qml` ~1105 lines, all state inline | `shell.qml` is now ~126 lines; all state in `services/` |
| `services/` didn't exist | All 15 backend singletons now live in `services/` |
| No `services/qmldir` | `services/qmldir` declares all 15 singletons |
| `shellRoot.X` references in consumers | All migrated to `Service.X` via `import "services"` |
| `configLoadComplete` etc. on `shellRoot` | All on `ConfigStore` singleton |
| `notificationServer` id in `shell.qml` | `Notifications` singleton wraps `NotificationServer`; toast bridge via `notificationReceived` signal |
| `icon(name)` on `shellRoot` | `Icons.icon(name)` singleton |
| Direct CLI in `QuickSettings`/`PowerMenu`/`VolumeSlider` | All moved to `services/Brightness` / `services/SystemActions` |
| `Lockscreen.qml` runs `awww query` | Now reads `Wallpapers.wallpaperPath` (singleton already queries) |
| `BottomBar.qml` runs `sh -c <exec>` | Now calls `SystemActions.launchEntry()` / `.launchExec()` |
| Five polling timers in `shell.qml` | Polling now lives in individual services (`Network`, `Bluetooth`, `Wallpapers`, `PowerProfiles`, `Brightness`, `Dock`) |
| Dead code: `killProc` / `savePinnedProc` in `shell.qml` | Gone — `killApp` is now `SystemActions.killApp()` |
| `ConfigStore` + `ConfigSaver` split planned | Combined `ConfigStore` singleton per user request |
