//@ pragma IconTheme breeze-dark

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications as Notifs
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import "components"
import "services"

ShellRoot {
    id: shellRoot

    // Appearance state (materialTheme, accentColor, blurEnabled, ...) lives
    // in services/Wallpapers.qml. Lock state lives in services/Lock.qml.

    IpcHandler {
        target: "lock"
        function toggle(): void { Lock.toggle(); }
        function lock(): void { Lock.lock(); }
        function unlock(): void { Lock.unlock(); }
    }

    // ── Notifications (extracted to services/Notifications.qml) ──
    // notificationServer, notificationList, dndActive, setDnd now live there.

    // ── Pipewire tracking ──
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // ── ConfigStore (extracted to services/ConfigStore.qml) ──
    // pinnedApps, toggleData, controlCenterLayout, mediaPlayerId,
    // loadConfig/saveConfig, getToggleSetting/setToggleSetting,
    // togglePin/movePinnedApp now live in the ConfigStore singleton.

    // ── Dock Logic ──
    property alias dockAppsModel: dockApps
    ListModel {
        id: dockApps
    }

    function refreshDock() {
        if (!Hyprland.toplevels) return;
        let toplevels = Hyprland.toplevels.values;
        let runningApps = [];
        let addedIds = new Set();
        let runningStates = {}; // Map of entry ID -> address
        let runningIdsList = []; // List of entry IDs for App Drawer
        let windowCounts = {}; // Map of entry ID -> number of windows
        let focusedEntryId = ""; // Entry ID of the currently focused app

        // 1. Collect all running applications via heuristic lookup
        for (let i = 0; i < toplevels.length; i++) {
            let tl = toplevels[i];
            let ipc = tl.lastIpcObject;
            let identifiers = [];
            
            if (ipc) {
                if (ipc.class) identifiers.push(ipc.class);
                if (ipc.initialClass) identifiers.push(ipc.initialClass);
            }
            let wcls = (tl.initialClass || tl.appId || (tl.wayland ? tl.wayland.appId : "") || "");
            if (wcls) identifiers.push(wcls);

            let entry = null;
            for (let id of identifiers) {
                entry = DesktopEntries.heuristicLookup(id);
                if (entry) break;
            }

            if (entry) {
                runningStates[entry.id] = ipc ? ipc.address : "";
                // Count windows per app
                windowCounts[entry.id] = (windowCounts[entry.id] || 0) + 1;
                // Check if this toplevel is the focused (activated) one
                if (tl.activated) {
                    focusedEntryId = entry.id;
                }
                if (!addedIds.has(entry.id)) {
                    runningIdsList.push(entry.id);
                    runningApps.push({
                        id: entry.id,
                        name: entry.name,
                        icon: entry.icon,
                        entry: entry,
                        isRunning: true,
                        isPinned: false,
                        address: ipc ? ipc.address : "",
                        windowCount: 0, // placeholder, set below
                        isFocused: false // placeholder, set below
                    });
                    addedIds.add(entry.id);
                }
            }
        }

        // Fill in windowCount and isFocused for running apps
        for (let app of runningApps) {
            app.windowCount = Math.min(windowCounts[app.id] || 1, 5);
            app.isFocused = (app.id === focusedEntryId);
        }
        
        // Update reactive running state for App Drawer
        shellRoot.runningAppIds = runningIdsList;

        let targetApps = [];
        let pinnedAdded = new Set();

        // 2. Build target list: Pinned first
        for (let pid of pinnedApps) {
            let entry = DesktopEntries.byId(pid) || DesktopEntries.heuristicLookup(pid);
            if (entry) {
                targetApps.push({
                    id: entry.id,
                    name: entry.name,
                    icon: entry.icon,
                    entry: entry,
                    isRunning: !!runningStates[entry.id],
                    isPinned: true,
                    address: runningStates[entry.id] || "",
                    windowCount: Math.min(windowCounts[entry.id] || 0, 5),
                    isFocused: (entry.id === focusedEntryId)
                });
                pinnedAdded.add(entry.id);
            }
        }

        // 3. Add remaining running apps
        for (let app of runningApps) {
            if (!pinnedAdded.has(app.id)) {
                targetApps.push(app);
            }
        }

        // 4. Incrementally update the ListModel (dockApps)
        // A. Remove items no longer present
        for (let i = dockApps.count - 1; i >= 0; i--) {
            let item = dockApps.get(i);
            if (!targetApps.find(a => a.id === item.id)) {
                dockApps.remove(i);
            }
        }

        // B. Add/Move/Update items to match target list
        for (let i = 0; i < targetApps.length; i++) {
            let target = targetApps[i];
            
            if (i < dockApps.count && dockApps.get(i).id === target.id) {
                // Just update state properties
                let existing = dockApps.get(i);
                if (existing.isRunning !== target.isRunning || existing.address !== target.address || existing.isPinned !== target.isPinned || existing.windowCount !== target.windowCount || existing.isFocused !== target.isFocused) {
                    dockApps.setProperty(i, "isRunning", target.isRunning);
                    dockApps.setProperty(i, "address", target.address);
                    dockApps.setProperty(i, "isPinned", target.isPinned);
                    dockApps.setProperty(i, "windowCount", target.windowCount);
                    dockApps.setProperty(i, "isFocused", target.isFocused);
                }
            } else {
                // Find target in current model
                let foundIndex = -1;
                for (let j = i + 1; j < dockApps.count; j++) {
                    if (dockApps.get(j).id === target.id) {
                        foundIndex = j;
                        break;
                    }
                }
                
                if (foundIndex !== -1) {
                    dockApps.move(foundIndex, i, 1);
                    dockApps.setProperty(i, "isRunning", target.isRunning);
                    dockApps.setProperty(i, "address", target.address);
                    dockApps.setProperty(i, "isPinned", target.isPinned);
                    dockApps.setProperty(i, "windowCount", target.windowCount);
                    dockApps.setProperty(i, "isFocused", target.isFocused);
                } else {
                    dockApps.insert(i, target);
                }
            }
        }
    }

    // Refresh dock when toplevels change
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() { shellRoot.refreshDock(); }
    }

    // Direct event connection for instant updates
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            let name = event.name
            if (name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "resizewindow" || name === "fullscreen" || name === "activewindow2" || name === "windowtitle") {
                Hyprland.refreshToplevels()
                shellRoot.refreshDock()
            }
        }
    }

    // ── UIState (extracted to services/UIState.qml) ──
    // panelOpen/powerMenuOpen/appDrawerOpen/switcherOpen/panelDragOffset/
    // barState/hasWindowsOnCurrentWs/hasSingleTiledWindow now live in UIState.

    // ── Network (extracted to services/Network.qml) ──
    // wifi/ethernet state and nmcli polling now live in Network.

    // ── Battery (extracted to services/Battery.qml) ──
    // batteryPct / batteryStatus now live in Battery.

    // ── PowerProfiles (extracted to services/PowerProfiles.qml) ──

    // ── Do Not Disturb (extracted to services/Notifications.qml) ──
    // dndActive + setDnd now live in Notifications.

    // ── Caffeine (extracted to services/Caffeine.qml) ──

    // ── Recorder (extracted to services/Recorder.qml) ──

    // ── Wallpapers (extracted to services/Wallpapers.qml) ──
    // wallpaperPath/blurVersion/blurredWallpaperPath/usePrecomputedBlur/
    // staticBlurEnabled/blurEnabled/materialTheme/accentColor now live in
    // Wallpapers. The 'appearance' IPC handlers delegate to it below.

    IpcHandler {
        target: "appearance"
        function setPrecomputedBlur(enabled: string): void { Wallpapers.setPrecomputedBlur(enabled); }
        function setBlurEnabled(enabled: string): void { Wallpapers.setBlurEnabled(enabled); }
        function setMaterial(material: string): void { Wallpapers.setMaterial(material); }
    }

    // ── UI Components (per-screen via Variants) ──
    Variants {
        model: Quickshell.screens
        Item {
            id: barStack
            required property var modelData
            // BackgroundBar is declared first so its z-order is below BottomBar.
            BackgroundBar {
                id: backgroundBar
                screen: barStack.modelData
                dockControl: bottomBar
            }
            BottomBar {
                id: bottomBar
                screen: barStack.modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens
        StatusBar {
            property var modelData
            screen: modelData
            batteryPct: Battery.batteryPct
            batteryStatus: Battery.batteryStatus
        }
    }
    Variants {
        model: Quickshell.screens
        QuickSettings {
            property var modelData
            screen: modelData
            batteryPct: Battery.batteryPct
            batteryStatus: Battery.batteryStatus
        }
    }
    NotificationPopup { id: globalToast }
    // Wire Notifications → global toast (only show when panel is closed).
    Connections {
        target: Notifications
        function onNotificationReceived(item) {
            if (!UIState.panelOpen) globalToast.show(item);
        }
    }
    Variants {
        model: Quickshell.screens
        TaskManager {
            property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        AppDrawer {
            property var modelData
            screen: modelData
        }
    }
    VolumeOSD {}
    PowerMenu {}

    // ── Context menu helpers live in services/UIState.qml ──
}
    // ── Do Not Disturb (extracted to services/Notifications.qml) ──
    // dndActive + setDnd now live in Notifications.

    // ── Caffeine ──
    property bool caffeineActive: false

    function setCaffeine(active) {
        shellRoot.caffeineActive = active;
        if (active) {
            caffeineProc.command = ["pkill", "-STOP", "hypridle"];
        } else {
            caffeineProc.command = ["pkill", "-CONT", "hypridle"];
        }
        caffeineProc.running = true;
    }

    Process {
        id: caffeineProc
        running: false
        onExited: (code) => {
            // If pkill failed (e.g., hypridle not running), revert the optimistic update
            if (code !== 0) {
                shellRoot.caffeineActive = !shellRoot.caffeineActive;
                console.warn("[Caffeine] pkill exited with code", code, "- reverted state");
            }
        }
    }

    // ── Screen Recording ──
    property bool isScreenRecording: screenRecordProc.running
    Process {
        id: screenRecordProc
        running: false
    }
    Process {
        id: stopScreenRecordProc
        command: ["pkill", "-SIGINT", "-f", "gpu-screen-recorder.*-o"]
        running: false
    }

    function toggleScreenRecording(audioIndex, fpsIndex, encoderIndex, resIndex, bitrateIndex) {
        if (isScreenRecording) {
            stopScreenRecordProc.running = true
        } else {
            let audioOptions = ["default_output", "default_input", "default_output|default_input", "none"]
            let fpsOptions = ["30", "45", "60"]
            let encoderOptions = ["auto", "h264", "hevc", "av1"]
            let resOptions = ["0x0"]
            let bitrateOptions = ["medium", "high", "very_high", "ultra"]

            // Clamp indices to valid range to defend against corrupted persisted state
            let aIdx = Math.max(0, Math.min(audioOptions.length - 1, parseInt(audioIndex) || 0));
            let fIdx = Math.max(0, Math.min(fpsOptions.length - 1, parseInt(fpsIndex) || 0));
            let eIdx = Math.max(0, Math.min(encoderOptions.length - 1, parseInt(encoderIndex) || 0));
            let rIdx = Math.max(0, Math.min(resOptions.length - 1, parseInt(resIndex) || 0));
            let bIdx = Math.max(0, Math.min(bitrateOptions.length - 1, parseInt(bitrateIndex) || 0));

            let aOpt = audioOptions[aIdx]
            let aStr = aOpt !== "none" ? `-a "${aOpt}"` : ""
            let cmd = `gpu-screen-recorder -w screen ${aStr} -f ${fpsOptions[fIdx]} -k ${encoderOptions[eIdx]} -s ${resOptions[rIdx]} -q ${bitrateOptions[bIdx]} -o ~/Videos/ScreenRecord-$(date +%Y%m%d-%H%M%S).mp4`

            screenRecordProc.command = ["sh", "-c", cmd]
            screenRecordProc.running = true
        }
    }

    // ── Wallpapers (extracted to services/Wallpapers.qml) ──
    // wallpaperPath/blurVersion/blurredWallpaperPath/usePrecomputedBlur/
    // staticBlurEnabled/blurEnabled/materialTheme/accentColor now live in
    // Wallpapers. The 'appearance' IPC handlers delegate to it below.

    IpcHandler {
        target: "appearance"
        function setPrecomputedBlur(enabled: string): void { Wallpapers.setPrecomputedBlur(enabled); }
        function setBlurEnabled(enabled: string): void { Wallpapers.setBlurEnabled(enabled); }
        function setMaterial(material: string): void { Wallpapers.setMaterial(material); }
    }

    // ── UI Components (per-screen via Variants) ──
    Variants {
        model: Quickshell.screens
        Item {
            id: barStack
            required property var modelData
            // BackgroundBar is declared first so its z-order is below BottomBar.
            BackgroundBar {
                id: backgroundBar
                screen: barStack.modelData
                dockControl: bottomBar
            }
            BottomBar {
                id: bottomBar
                screen: barStack.modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens
        StatusBar {
            property var modelData
            screen: modelData
            batteryPct: Battery.batteryPct
            batteryStatus: Battery.batteryStatus
        }
    }
    Variants {
        model: Quickshell.screens
        QuickSettings {
            property var modelData
            screen: modelData
            batteryPct: Battery.batteryPct
            batteryStatus: Battery.batteryStatus
        }
    }
    NotificationPopup { id: globalToast }
    // Wire Notifications → global toast (only show when panel is closed).
    Connections {
        target: Notifications
        function onNotificationReceived(item) {
            if (!UIState.panelOpen) globalToast.show(item);
        }
    }
    Variants {
        model: Quickshell.screens
        TaskManager {
            property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        AppDrawer {
            property var modelData
            screen: modelData
        }
    }
    VolumeOSD {}
    PowerMenu {}

    // ── Context menu helpers live in services/UIState.qml ──
}
