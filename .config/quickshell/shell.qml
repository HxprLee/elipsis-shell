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

ShellRoot {
    id: shellRoot

    property string materialTheme: "Acrylic"
    property bool isLocked: false
    property var accentColor: null

    WlSessionLock {
        id: sessionLock
        locked: shellRoot.isLocked
        surface: Lockscreen {}
    }

    function lock() {
        shellRoot.isLocked = true
    }

    function unlock() {
        shellRoot.isLocked = false
    }

    IpcHandler {
        target: "lock"

        function toggle(): void {
            if (shellRoot.isLocked) shellRoot.unlock();
            else shellRoot.lock();
        }

        function lock(): void {
            shellRoot.lock();
        }

        function unlock(): void {
            shellRoot.unlock();
        }
    }

    // ── Notification Server ──
    Notifs.NotificationServer {
        id: notificationServer

        property var notificationList: []

        onNotification: (notification) => {
            let item = {
                id: notification.id,
                appName: notification.appName,
                appIcon: notification.appIcon ?? "",
                summary: notification.summary,
                body: notification.body,
                timeout: notification.expireTimeout,
                timestamp: Date.now()
            };
            console.log("Notification received: ", item.summary);
            let copy = notificationList.slice();
            let found = false;
            for (let i = 0; i < copy.length; i++) {
                if (copy[i].id === item.id) {
                    copy[i] = item;
                    found = true;
                    break;
                }
            }
            if (!found) copy.unshift(item);
            notificationList = copy;
            
            // Trigger iOS Popup Drop-down (unless DND)
            if (!shellRoot.dndActive) globalToast.show(item);
        }

        function dismiss(nid) {
            notificationList = notificationList.filter(n => n.id !== nid);
        }
        function dismissByApp(appName) {
            notificationList = notificationList.filter(n => n.appName !== appName);
        }
        function clearAll() {
            notificationList = [];
        }
    }

    // ── Pipewire tracking ──
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // ── Unified Config ──
    property var pinnedApps: []
    property var runningAppIds: []
    property var toggleData: ({})
    property bool toggleDataLoaded: false
    property var controlCenterLayout: []
    property string mediaPlayerId: ""
    property bool configLoadComplete: false
    property bool _loadingConfig: false

    Process {
        id: loadConfigProc
        command: ["cat", Qt.resolvedUrl("config/config.json").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                shellRoot._loadingConfig = true;
                console.log("[Config] Raw:", text);
                try {
                    let cfg = JSON.parse(text) || {};
                    console.log("[Config] Parsed:", JSON.stringify(cfg));

                    if (cfg.pinnedApps) shellRoot.pinnedApps = cfg.pinnedApps;
                    if (cfg.toggleData) {
                        shellRoot.toggleData = cfg.toggleData;
                        shellRoot.dndActive = !!cfg.toggleData["DndToggle"]?.active;
                    }
                    shellRoot.toggleDataLoaded = true;

                    let app = cfg.appearance || {};
                    if (app.materialTheme !== undefined) shellRoot.materialTheme = app.materialTheme;
                    if (app.staticBlurEnabled !== undefined) shellRoot.staticBlurEnabled = app.staticBlurEnabled;
                    if (app.blurEnabled !== undefined) shellRoot.blurEnabled = app.blurEnabled;
                    if (app.accentColor !== undefined && app.accentColor !== null && app.accentColor !== "") {
                        let c = app.accentColor;
                        if (typeof c === "string" && c.startsWith("#")) {
                            let hex = c.slice(1);
                            // Validate hex string is 6 or 8 hex chars and all parseable
                            if (/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(hex)) {
                                // Round to 8-bit precision to match saveConfig() output
                                // and avoid triggering a save→reload cycle
                                let r = Math.round(parseInt(hex.slice(0, 2), 16) / 255 * 255) / 255;
                                let g = Math.round(parseInt(hex.slice(2, 4), 16) / 255 * 255) / 255;
                                let b = Math.round(parseInt(hex.slice(4, 6), 16) / 255 * 255) / 255;
                                let a = hex.length === 8 ? Math.round(parseInt(hex.slice(6, 8), 16) / 255 * 255) / 255 : 1.0;
                                if (!isNaN(r) && !isNaN(g) && !isNaN(b) && !isNaN(a)) {
                                    shellRoot.accentColor = Qt.rgba(r, g, b, a);
                                }
                            }
                        } else {
                            shellRoot.accentColor = c;
                        }
                    }
                    if (app.wallpaperPath !== undefined) shellRoot.wallpaperPath = app.wallpaperPath;

                    if (cfg.layout && cfg.layout.length > 0) shellRoot.controlCenterLayout = cfg.layout;
                    if (cfg.mediaPlayerId) shellRoot.mediaPlayerId = cfg.mediaPlayerId;
                    console.log("[Config] Layout:", JSON.stringify(shellRoot.controlCenterLayout));

                    shellRoot.refreshDock();
                    shellRoot.configLoadComplete = true;
                    console.log("[Config] Loaded successfully");
                } catch (e) {
                    console.error("Config load error:", e);
                    shellRoot.configLoadComplete = true;
                }
                shellRoot._loadingConfig = false;
            }
        }
    }

    FileView {
        path: Qt.resolvedUrl("config/config.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: {
            if (!loadConfigProc.running) loadConfigProc.running = true
        }
    }

    Process { id: saveConfigProc; running: false }

    function saveConfig() {
        if (!shellRoot.configLoadComplete || shellRoot._loadingConfig) return;
        let accentColorHex = null;
        if (shellRoot.accentColor) {
            let c = shellRoot.accentColor;
            let r = Math.round(c.r * 255).toString(16).padStart(2, '0');
            let g = Math.round(c.g * 255).toString(16).padStart(2, '0');
            let b = Math.round(c.b * 255).toString(16).padStart(2, '0');
            let a = Math.round(c.a * 255).toString(16).padStart(2, '0');
            accentColorHex = "#" + r + g + b + (a !== "ff" ? a : "");
        }
        let cfg = {
            pinnedApps: shellRoot.pinnedApps,
            toggleData: shellRoot.toggleData,
            appearance: {
                materialTheme: shellRoot.materialTheme,
                staticBlurEnabled: shellRoot.staticBlurEnabled,
                blurEnabled: shellRoot.blurEnabled,
                accentColor: accentColorHex,
                wallpaperPath: shellRoot.wallpaperPath || ""
            },
            layout: shellRoot.controlCenterLayout,
            mediaPlayerId: shellRoot.mediaPlayerId
        };
        let path = Qt.resolvedUrl("config/config.json").toString().replace("file://", "");
        saveConfigProc.command = ["sh", "-c", "echo \"$1\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"", "sh", JSON.stringify(cfg, null, 2), path];
        saveConfigProc.running = true;
    }

    function savePinnedApps() { saveConfig(); }
    function saveToggleData() { saveConfig(); }
    function saveAppearance() { saveConfig(); }

    function getToggleSetting(toggleId, key, defaultValue) {
        if (!toggleData[toggleId]) return defaultValue;
        if (toggleData[toggleId][key] === undefined) return defaultValue;
        return toggleData[toggleId][key];
    }

    function setToggleSetting(toggleId, key, value) {
        let currentData = Object.assign({}, toggleData);
        if (!currentData[toggleId]) currentData[toggleId] = {};
        currentData[toggleId][key] = value;
        toggleData = currentData;
        saveConfig();
    }

    function movePinnedApp(fromId, toId) {
        let copy = pinnedApps.map(id => id.toLowerCase());
        let fid = fromId.toLowerCase();
        let tid = toId.toLowerCase();
        
        let fromIdx = copy.indexOf(fid);
        let toIdx = copy.indexOf(tid);
        
        if (fromIdx === -1) {
            // New pin from running app - ensure it doesn't already exist
            if (toIdx === -1) copy.push(fid);
            else copy.splice(toIdx, 0, fid);
        } else if (fromIdx !== toIdx) {
            // Move logic - adjust toIdx after removal if needed
            let item = copy.splice(fromIdx, 1)[0];
            // After splice, items after fromIdx shifted left by 1
            let adjustedToIdx = toIdx === -1 ? -1 : (toIdx > fromIdx ? toIdx - 1 : toIdx);
            if (adjustedToIdx === -1) {
                copy.push(item);
            } else {
                copy.splice(adjustedToIdx, 0, item);
            }
        }
        
        // Remove any accidental duplicates just in case
        shellRoot.pinnedApps = copy.filter((v, i, a) => a.indexOf(v) === i);
        shellRoot.savePinnedApps();
        shellRoot.refreshDock();
    }

    function togglePin(appId) {
        let lowerId = appId.toLowerCase();
        let copy = pinnedApps.slice();
        let index = copy.indexOf(lowerId);
        if (index === -1) {
            copy.push(lowerId);
        } else {
            copy.splice(index, 1);
        }
        shellRoot.pinnedApps = copy;
        shellRoot.savePinnedApps();
        shellRoot.refreshDock();
    }

    function killApp(entryId) {
        let toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            let tl = toplevels[i];
            let ipc = tl.lastIpcObject;
            if (!ipc) continue;
            
            // Re-run the lookup for this window to see if it belongs to the target entry
            let identifiers = [ipc.class, ipc.initialClass, tl.initialClass, tl.appId].filter(x => !!x);
            let match = false;
            for (let id of identifiers) {
                let entry = DesktopEntries.heuristicLookup(id);
                if (entry && entry.id === entryId) {
                    match = true;
                    break;
                }
            }
            
            if (match) {
                let safeAddr = ipc.address.toString().replace(/[^0-9a-fA-Fx]/g, "");
                Hyprland.dispatch("hl.dsp.window.close({ window = 'address:" + safeAddr + "' })");
            }
        }
    }

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

    // Auto-save appearance settings on change
    Connections {
        target: shellRoot
        function onMaterialThemeChanged() { saveAppearance(); }
        function onBlurEnabledChanged() { saveAppearance(); }
        function onAccentColorChanged() { saveAppearance(); }
        function onWallpaperPathChanged() { saveAppearance(); }
        function onStaticBlurEnabledChanged() { saveAppearance(); }
    }

    // ── Shared UI state ──
    property bool panelOpen: false
    property real panelDragOffset: 0.0
    property bool switcherOpen: false
    property bool appDrawerOpen: false
    property bool powerMenuOpen: false

    function closeOtherOverlays(except) {
        if (except !== "panel") shellRoot.panelOpen = false;
        if (except !== "power") shellRoot.powerMenuOpen = false;
        if (except !== "drawer") shellRoot.appDrawerOpen = false;
        if (except !== "switcher") shellRoot.switcherOpen = false;
    }

    // ── Window tracking ──
    property bool hasWindowsOnCurrentWs: {
        const ws = Hyprland.focusedWorkspace;
        if (!ws) return false;
        
        const toplevels = ws.toplevels.values;
        if (toplevels.length === 0) return false;

        let hasNonFloating = false;
        let anyOverlap = false;

        const dockHeight = 112; // Height of the uncollapsed dock
        
        // Use Quickshell.screens to find the logical height of the focused monitor
        let mon = null;
        const focusedMon = Hyprland.focusedMonitor;
        if (focusedMon) {
            for (let s of Quickshell.screens) {
                if (s.name === focusedMon.name) {
                    mon = s;
                    break;
                }
            }
        }
        
        if (!mon) mon = (Quickshell.screens.length > 0) ? Quickshell.screens[0] : null;
        if (!mon) return false;
        
        const monitorBottom = mon.y + mon.height;

        for (let i = 0; i < toplevels.length; i++) {
            const tl = toplevels[i];
            const ipc = tl.lastIpcObject;
            if (!ipc) continue;
            
            // Determine floating status robustly
            const isFloating = (tl.floating !== undefined) ? tl.floating : !!ipc.floating;

            if (!isFloating) {
                hasNonFloating = true;
                break;
            } else {
                const y = (ipc.at && ipc.at.length > 1) ? ipc.at[1] : 0;
                const h = (ipc.size && ipc.size.length > 1) ? ipc.size[1] : 0;
                const windowBottom = y + h;
                const hotZoneStart = monitorBottom - dockHeight - 5;

                // DIAGNOSTIC LOGGING
                // console.log(`[Dock Detect] Window: "${tl.title}" | floating: ${isFloating} | y=${y}, h=${h} (bottom=${windowBottom}) | HotZoneStart=${hotZoneStart}`);

                if (windowBottom > hotZoneStart) {
                    anyOverlap = true;
                    break;
                }
            }
        }

        return hasNonFloating || anyOverlap;
    }

    // True when the focused workspace has exactly one tiled (non-floating)
    // window. Used by BackgroundBar.qml to drive the dim layer.
    property bool hasSingleTiledWindow: {
        let ws = Hyprland.focusedMonitor?.activeWorkspace;
        if (!ws) return false;
        let toplevels = Hyprland.toplevels.values;
        let tiledCount = 0;
        for (let i = 0; i < toplevels.length; i++) {
            let tl = toplevels[i];
            if (!tl) continue;
            let ipc = tl.lastIpcObject;
            if (!ipc) continue;
            if (ipc.workspace?.id === ws.id && !ipc.floating) {
                tiledCount++;
                if (tiledCount > 1) return false;
            }
        }
        return tiledCount === 1;
    }

    // Dock state machine: "handle" (collapsed pill), "dock" (expanded),
    // "overlay" (expanded + auto-hide). Written by BottomBar.qml's gesture
    // and lock timers; read by BackgroundBar.qml for the dim trigger.
    property string barState: "handle"

    // Heartbeat for dock population
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            Hyprland.refreshToplevels()
            shellRoot.refreshDock()
        }
    }

    // ── Global Network & Bluetooth State ──
    property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi) return devices[i];
        }
        return null;
    }

    property bool wifiEnabled: Networking.wifiEnabled ?? false
    property bool wifiConnected: !!(wifiDevice && wifiDevice.connected)

    property var ethernetDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Ethernet) return devices[i];
        }
        return null;
    }
    property string networkName: ""
    property string activeEthernetName: ""
    property string ethernetIface: ""
    
    Process {
        id: netPollProc
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME con show --active | grep -E '802-11-wireless|wireless|802-3-ethernet|ethernet|wired'; nmcli -t -f DEVICE,TYPE device | grep -iE 'ethernet|wired'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n");
                let wifi = "";
                let eth = "";
                let iface = "";
                
                for (let line of lines) {
                    let parts = line.split(":");
                    if (parts.length < 2) continue;
                    let type = parts[0].toLowerCase();
                    let name = parts[1];
                    
                    if (type.includes("wireless") || type.includes("wifi")) {
                        if (wifi === "") wifi = name;
                    } else if (type.includes("ethernet") || type.includes("wired")) {
                        // nmcli device output format is DEVICE:TYPE
                        // nmcli con show output format is TYPE:NAME
                        if (line.includes(":") && !name.includes("ethernet") && !name.includes("wired")) {
                             iface = parts[0];
                        } else {
                             eth = name;
                        }
                    }
                }
                
                shellRoot.networkName = wifi;
                shellRoot.activeEthernetName = eth;
                if (iface !== "") shellRoot.ethernetIface = iface;
            }
        }
    }
    
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: netPollProc.running = true
    }

    Process {
        id: ethToggleProc
        running: false
    }

    function disconnectEthernet() {
        if (activeEthernetName) {
            ethToggleProc.command = ["nmcli", "connection", "down", activeEthernetName];
            ethToggleProc.running = true;
        }
    }

    function connectEthernet() {
        if (ethernetIface !== "") {
            ethToggleProc.command = ["nmcli", "device", "connect", ethernetIface];
            ethToggleProc.running = true;
        }
    }

    property bool ethernetConnected: activeEthernetName !== ""
    property bool networkEnabled: wifiConnected || ethernetConnected
    property bool networkConnected: wifiConnected || ethernetConnected
    property string networkType: ethernetConnected ? "ethernet" : "wifi"

    // Signal level from 0 to 4
    property int networkSignalLevel: {
        if (!wifiDevice || !wifiDevice.connected || !wifiDevice.networks) return 0;
        const networks = wifiDevice.networks.values;
        for (let i = 0; i < networks.length; i++) {
            let net = networks[i];
            if (net.connected) {
                let s = net.signalStrength;
                if (s >= 0.8) return 4;
                if (s >= 0.6) return 3;
                if (s >= 0.4) return 2;
                if (s >= 0.2) return 1;
                return 0;
            }
        }
        return 0;
    }

    property bool bluetoothEnabledManual: false
    property bool bluetoothEnabled: {
        if (bluetoothEnabledManual) return true;
        if (Bluetooth.adapter) return !!Bluetooth.adapter.powered;
        if (Bluetooth.adapters && Bluetooth.adapters.values && Bluetooth.adapters.values.length > 0) {
            return !!Bluetooth.adapters.values[0].powered;
        }
        return false;
    }

    Timer {
        interval: 2500; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: btStatusProc.running = true
    }

    Process {
        id: btStatusProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes'"]
        running: false
        onExited: (code) => {
            shellRoot.bluetoothEnabledManual = (code === 0);
        }
    }
    property bool bluetoothConnected: connectedBluetoothDevices.length > 0

    property string bluetoothDeviceName: {
        if (connectedBluetoothDevices.length > 0) {
            let d = connectedBluetoothDevices[0];
            return d.name || d.alias || "Connected";
        }
        return "";
    }

    property var connectedBluetoothDevices: {
        if (!Bluetooth.devices) return [];
        return Bluetooth.devices.values.filter(d => d.connected);
    }

    property bool bluetoothScanningManual: btScanProc.running
    function startBluetoothDiscovery() {
        if (Bluetooth.adapter) {
            Bluetooth.adapter.discovering = true;
        } else if (Bluetooth.adapters && Bluetooth.adapters.values && Bluetooth.adapters.values.length > 0) {
            Bluetooth.adapters.values[0].discovering = true;
        }
        
        // Fallback for systems where native discovery trigger fails
        if (!btScanProc.running) {
            btScanProc.running = true;
        }
    }

    Process {
        id: btScanProc
        command: ["sh", "-c", "bluetoothctl --timeout 15 scan on"]
        running: false
    }

    property bool isScanningNetwork: networkScanProc.running
    function refreshNetwork() {
        if (networkScanProc.running) return;

        if (Networking.wifi) {
            Networking.wifi.scan();
        }
        
        networkScanProc.running = true;
    }

    Process {
        id: networkScanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        running: false
    }

    function toggleBluetooth() {
        if (btToggleProc.running) return;
        let cmd = "bluetoothctl power " + (shellRoot.bluetoothEnabled ? "off" : "on")
        console.log("Bluetooth Toggle Command:", cmd)
        btToggleProc.command = ["sh", "-c", cmd]
        btToggleProc.running = true
    }

    function toggleWifi() {
        if (wifiToggleProc.running) return;
        wifiToggleProc.command = ["sh", "-c", "nmcli radio wifi " + (shellRoot.wifiEnabled ? "off" : "on")]
        wifiToggleProc.running = true
    }

    Process { id: btToggleProc; running: false }
    Process { id: wifiToggleProc; running: false }

    // ── Battery via UPower ──
    property int batteryPct: -1
    property string batteryStatus: ""

    Binding on batteryPct {
        value: UPower.displayDevice && UPower.displayDevice.percentage >= 0.01
            ? Math.round(UPower.displayDevice.percentage * 100)
            : -1
    }
    Binding on batteryStatus {
        value: UPower.displayDevice
            ? UPowerDeviceState.toString(UPower.displayDevice.state)
            : ""
    }

    Component.onCompleted: {
        console.log("UPower displayDevice:", UPower.displayDevice);
        console.log("UPower displayDevice percentage:", UPower.displayDevice?.percentage);
        console.log("UPower displayDevice state:", UPower.displayDevice?.state);
    }

    // ── Power Profiles ──
    property string powerProfile: "balanced"

    Process {
        id: getPowerProfileProc
        command: ["busctl", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"]
        running: false
        stdout: SplitParser { 
            onRead: data => { 
                // data looks like: s "performance"
                let parts = data.trim().split('"');
                if (parts.length >= 2) {
                    shellRoot.powerProfile = parts[1];
                }
            } 
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            getPowerProfileProc.running = true;
        }
    }

    Process { id: setPowerProfileProc; running: false }

    function setPowerProfile(profile) {
        shellRoot.powerProfile = profile; // optimistic update
        setPowerProfileProc.command = ["busctl", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile", "s", profile];
        setPowerProfileProc.running = true;
    }

    // ── Do Not Disturb ──
    property bool dndActive: false

    function setDnd(active) {
        shellRoot.dndActive = active;
        shellRoot.setToggleSetting("DndToggle", "active", active);
    }

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

    // ── Icon helper (direct lookup for breeze-dark) ──
    function icon(name) {
        let table = {
            "network-wireless-signal-excellent-symbolic": "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-excellent-symbolic.svg",
            "network-wireless-signal-good-symbolic":      "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-good-symbolic.svg",
            "network-wireless-signal-ok-symbolic":        "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-ok-symbolic.svg",
            "network-wireless-signal-weak-symbolic":      "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-weak-symbolic.svg",
            "network-wireless-signal-none-symbolic":      "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-none-symbolic.svg",
            "network-wireless-offline-symbolic":          "file:///usr/share/icons/breeze-dark/actions/24/network-disconnect-symbolic.svg",
            "network-disconnect-symbolic":                "file:///usr/share/icons/breeze-dark/actions/24/network-disconnect-symbolic.svg",
            "network-wireless-symbolic":                  "file:///usr/share/icons/breeze-dark/devices/24/network-wireless-symbolic.svg",
            "network-wired-symbolic":                     "file:///usr/share/icons/breeze-dark/devices/24/network-wired-symbolic.svg",
            "network-wired-offline-symbolic":             "file:///usr/share/icons/breeze-dark/actions/24/network-disconnect-symbolic.svg",
            "bluetooth-active-symbolic":           "file:///usr/share/icons/breeze-dark/preferences/24/preferences-system-bluetooth-activated-symbolic.svg",
            "bluetooth-disabled-symbolic":         "file:///usr/share/icons/breeze-dark/preferences/24/preferences-system-bluetooth-inactive-symbolic.svg",
            "preferences-system-symbolic":         "file:///usr/share/icons/breeze-dark/actions/24/preferences-system-symbolic.svg",
            "system-lock-screen-symbolic":         "file:///usr/share/icons/breeze-dark/actions/24/system-lock-screen-symbolic.svg",
            "system-shutdown-symbolic":            "file:///usr/share/icons/breeze-dark/actions/24/system-shutdown-symbolic.svg",
            "display-brightness-symbolic":         "file:///usr/share/icons/breeze-dark/actions/24/high-brightness-symbolic.svg",
            "audio-volume-high-symbolic":          "file:///usr/share/icons/breeze-dark/status/24/audio-volume-high-symbolic.svg",
            "audio-volume-medium-symbolic":        "file:///usr/share/icons/breeze-dark/status/24/audio-volume-medium-symbolic.svg",
            "audio-volume-low-symbolic":           "file:///usr/share/icons/breeze-dark/status/24/audio-volume-low-symbolic.svg",
            "audio-volume-muted-symbolic":         "file:///usr/share/icons/breeze-dark/status/24/audio-volume-muted-symbolic.svg",
            "battery-missing-symbolic":            "file:///usr/share/icons/breeze-dark/status/24/battery-missing-symbolic.svg",
            "window-close-symbolic":               "file:///usr/share/icons/breeze-dark/actions/24/window-close-symbolic.svg",
            "view-app-grid-symbolic":              "file:///usr/share/icons/breeze-dark/actions/24/view-grid-symbolic.svg",
            "go-up-symbolic":                      "file:///usr/share/icons/breeze-dark/actions/24/go-up-symbolic.svg",
            "edit-clear-all-symbolic":             "file:///usr/share/icons/breeze-dark/actions/24/edit-clear-all-symbolic.svg",
            "go-next-symbolic":                    "file:///usr/share/icons/breeze-dark/actions/24/go-next-symbolic.svg",
            "view-refresh-symbolic":               "file:///usr/share/icons/breeze-dark/actions/24/view-refresh-symbolic.svg",
            "object-select-symbolic":              "file:///usr/share/icons/breeze-dark/actions/16/object-select-symbolic.svg",
            "notifications-disabled-symbolic":     "file:///usr/share/icons/breeze-dark/actions/24/notifications-disabled-symbolic.svg",
            "emblem-ok-symbolic":                  "file:///usr/share/icons/breeze-dark/emblems/16/emblem-ok-symbolic.svg",
            "system-reboot-symbolic":              "file:///usr/share/icons/breeze-dark/actions/24/system-reboot-symbolic.svg",
            "system-suspend-symbolic":             "file:///usr/share/icons/breeze-dark/actions/24/system-suspend-symbolic.svg",
            "power-profile-power-saver":           "file:///usr/share/icons/breeze-dark/status/22/battery-profile-powersave-symbolic.svg",
            "power-profile-balanced":              "file:///usr/share/icons/breeze-dark/status/22/battery-profile-balanced-symbolic.svg",
            "power-profile-performance":           "file:///usr/share/icons/breeze-dark/status/22/battery-profile-performance-symbolic.svg",
            "system-suspend-inhibited-symbolic":   "file:///usr/share/icons/breeze-dark/status/24/system-suspend-inhibited.svg",
            "multimedia-audio-player-symbolic":    "file:///usr/share/icons/breeze-dark/apps/48/multimedia-audio-player.svg",
            "spotify":                             "file:///usr/share/icons/breeze-dark/apps/48/spotify-client.svg",
            "vlc":                                 "file:///usr/share/icons/breeze-dark/apps/48/vlc.svg",
            "elisa":                               "file:///usr/share/icons/breeze-dark/apps/48/elisa.svg",
            "mpv":                                 "file:///usr/share/icons/breeze-dark/apps/48/mpv.svg",
            "firefox":                             "file:///usr/share/icons/breeze-dark/apps/48/firefox.svg",
            "chromium":                            "file:///usr/share/icons/breeze-dark/apps/48/chromium-browser.svg",
            };

            if (table[name]) return table[name];

            if (name.startsWith("battery-")) {
            return "file:///usr/share/icons/breeze-dark/status/24/" + name + ".svg";
            }

            if (name.startsWith("media-")) {
            return "file:///usr/share/icons/breeze-dark/actions/24/" + name + ".svg";
            }

            if (name.startsWith("multimedia-")) {
            return "file:///usr/share/icons/breeze-dark/apps/48/" + name.replace("-symbolic", "") + ".svg";
            }        
        return "";
    }

    // ── Wallpaper & Blur ──
    property string wallpaperPath: ""
    property int blurVersion: 0
    property string blurredWallpaperPath: "file:///tmp/elipsis_blur.png"
    property bool usePrecomputedBlur: true
    property bool staticBlurEnabled: true
    property bool blurEnabled: true

    Process {
        id: wallpaperQuery
        command: ["awww", "query"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                let match = line.match(/image: (.*)/);
                if (match) {
                    let path = match[1].trim();
                    if (shellRoot.wallpaperPath !== path) {
                        shellRoot.wallpaperPath = path;
                        if (shellRoot.usePrecomputedBlur) blurGenerator.startBlur();
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000 // Poll wallpaper every 2s for snappier response
        running: true
        repeat: true
        onTriggered: if (!wallpaperQuery.running) wallpaperQuery.running = true
    }

    Process {
        id: blurGenerator
        function startBlur() {
            if (shellRoot.wallpaperPath === "") return;
            // High-speed optimization: 
            // 1. Use -sample for ultra-fast downscaling (5%)
            // 2. Use -blur with small radius on tiny image
            // 3. Use -resize for smooth upscaling back to 100%
            command = ["magick", shellRoot.wallpaperPath, "-sample", "5%", "-blur", "0x2", "-resize", "2000%", "/tmp/elipsis_blur.png"];
            running = true;
        }
        onExited: (code) => {
            if (code === 0) shellRoot.blurVersion++;
        }
    }

    IpcHandler {
        target: "appearance"
        function setPrecomputedBlur(enabled: string) {
            let s = String(enabled).toLowerCase();
            let isEnabled = (s === "true" || s === "1" || s === "yes" || s === "on");
            shellRoot.usePrecomputedBlur = isEnabled;
            if (isEnabled && shellRoot.wallpaperPath !== "") blurGenerator.startBlur();
        }

        function setBlurEnabled(enabled: string) {
            let s = String(enabled).toLowerCase();
            let isEnabled = (s === "true" || s === "1" || s === "yes" || s === "on");
            shellRoot.blurEnabled = isEnabled;
        }

        function setMaterial(material: string) {
            if (typeof material !== "string") return;
            if (["Solid", "Acrylic", "Frosted Glass"].includes(material)) {
                shellRoot.materialTheme = material;
            } else {
                console.warn("Unknown material:", material);
            }
        }
    }

    IpcHandler {
        target: "power"
        function show() {
            shellRoot.closeOtherOverlays("power");
            shellRoot.powerMenuOpen = true;
        }
        function hide() {
            shellRoot.powerMenuOpen = false;
        }
        function toggle() {
            if (shellRoot.powerMenuOpen) {
                shellRoot.powerMenuOpen = false;
            } else {
                shellRoot.closeOtherOverlays("power");
                shellRoot.powerMenuOpen = true;
            }
        }
    }

    IpcHandler {
        target: "quicksettings"
        function show() {
            shellRoot.closeOtherOverlays("panel");
            shellRoot.panelOpen = true;
        }
        function hide() {
            shellRoot.panelOpen = false;
        }
        function toggle() {
            if (shellRoot.panelOpen) {
                shellRoot.panelOpen = false;
            } else {
                shellRoot.closeOtherOverlays("panel");
                shellRoot.panelOpen = true;
            }
        }
    }

    IpcHandler {
        target: "task_manager"
        function toggle() {
            if (shellRoot.switcherOpen) {
                shellRoot.switcherOpen = false;
            } else {
                shellRoot.closeOtherOverlays("switcher");
                shellRoot.switcherOpen = true;
            }
        }
        function open() {
            shellRoot.closeOtherOverlays("switcher");
            shellRoot.switcherOpen = true;
        }
        function close() {
            shellRoot.switcherOpen = false;
        }
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
            batteryPct: shellRoot.batteryPct
            batteryStatus: shellRoot.batteryStatus
        }
    }
    Variants {
        model: Quickshell.screens
        QuickSettings {
            property var modelData
            screen: modelData
            batteryPct: shellRoot.batteryPct
            batteryStatus: shellRoot.batteryStatus
        }
    }
    NotificationPopup { id: globalToast }
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

    // ── Context Menu Helpers ──
    // Per-screen context menu windows keyed by screen name
    property var _contextMenus: ({})

    // Open a context menu at the cursor position on the given screen
    function openContextMenuAtCursor(screen, model) {
        closeContextMenu(screen);

        // Get cursor position from Hyprland
        let cursor = Hyprland.cursorPosition;
        let x = cursor ? cursor.x : (screen ? screen.x + screen.width / 2 : 0);
        let y = cursor ? cursor.y : (screen ? screen.y + screen.height / 2 : 0);

        let menuComponent = Qt.createComponent("components/reusables/ContextMenu.qml");
        if (menuComponent.status === Component.Ready) {
            let menuWindow = menuComponent.createObject(shellRoot, {
                "targetScreen": screen,
                "autoDestroy": true,
                "model": model,
                "menuX": x,
                "menuY": y
            });

            if (menuWindow) {
                _contextMenus[screen ? screen.name : "default"] = menuWindow;
                menuWindow.open(screen, model, x, y);
            } else {
                console.error("[ShellRoot] Failed to create context menu:", menuComponent.errorString());
            }
        } else {
            console.error("[ShellRoot] Failed to load ContextMenu.qml:", menuComponent.errorString());
        }
    }

    // Close the context menu on the given screen
    function closeContextMenu(screen) {
        let key = screen ? screen.name : "default";
        if (_contextMenus[key]) {
            _contextMenus[key].close();
            delete _contextMenus[key];
        }
    }

    // Close all open context menus
    function closeAllContextMenus() {
        for (let key in _contextMenus) {
            if (_contextMenus[key]) {
                _contextMenus[key].close();
            }
        }
        _contextMenus = ({});
    }
}
