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
            
            // Trigger iOS Popup Drop-down
            globalToast.show(item);
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
    property bool configLoadComplete: false

    Process {
        id: loadConfigProc
        command: ["cat", Qt.resolvedUrl("config/config.json").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                console.log("[Config] Raw:", text);
                try {
                    let cfg = JSON.parse(text) || {};
                    console.log("[Config] Parsed:", JSON.stringify(cfg));

                    if (cfg.pinnedApps) shellRoot.pinnedApps = cfg.pinnedApps;
                    if (cfg.toggleData) shellRoot.toggleData = cfg.toggleData;
                    shellRoot.toggleDataLoaded = true;

                    let app = cfg.appearance || {};
                    if (app.materialTheme !== undefined) shellRoot.materialTheme = app.materialTheme;
                    if (app.staticBlurEnabled !== undefined) shellRoot.staticBlurEnabled = app.staticBlurEnabled;
                    if (app.blurEnabled !== undefined) shellRoot.blurEnabled = app.blurEnabled;
                    if (app.accentColor !== undefined && app.accentColor !== null && app.accentColor !== "") {
                        let c = app.accentColor;
                        if (typeof c === "string" && c.startsWith("#")) {
                            let hex = c.slice(1);
                            let r = parseInt(hex.slice(0, 2), 16) / 255;
                            let g = parseInt(hex.slice(2, 4), 16) / 255;
                            let b = parseInt(hex.slice(4, 6), 16) / 255;
                            let a = hex.length === 8 ? parseInt(hex.slice(6, 8), 16) / 255 : 1.0;
                            shellRoot.accentColor = Qt.rgba(r, g, b, a);
                        } else {
                            shellRoot.accentColor = c;
                        }
                    }
                    if (app.wallpaperPath !== undefined) shellRoot.wallpaperPath = app.wallpaperPath;

                    if (cfg.layout && cfg.layout.length > 0) shellRoot.controlCenterLayout = cfg.layout;
                    console.log("[Config] Layout:", JSON.stringify(shellRoot.controlCenterLayout));

                    shellRoot.refreshDock();
                    shellRoot.configLoadComplete = true;
                    console.log("[Config] Loaded successfully");
                } catch (e) {
                    console.error("Config load error:", e);
                    shellRoot.configLoadComplete = true;
                }
            }
        }
    }

    FileView {
        path: Qt.resolvedUrl("config/config.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: loadConfigProc.running = true
    }

    Process { id: saveConfigProc; running: false }

    function saveConfig() {
        if (!shellRoot.configLoadComplete) return;
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
            layout: shellRoot.controlCenterLayout
        };
        let path = Qt.resolvedUrl("config/config.json").toString().replace("file://", "");
        saveConfigProc.command = ["sh", "-c", "echo \"$1\" > \"$2\"", "sh", JSON.stringify(cfg, null, 2), path];
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
            // Swap logic
            let item = copy.splice(fromIdx, 1)[0];
            if (toIdx === -1) {
                copy.push(item);
            } else {
                copy.splice(toIdx, 0, item);
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
                Hyprland.dispatch("hl.dsp.window.close({ window = 'address:" + ipc.address + "' })");
            }
        }
    }

    Process { id: killProc; running: false }

    Process {
        id: savePinnedProc
        running: false
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
    }

    // ── Shared UI state ──
    property bool panelOpen: false
    property real panelDragOffset: 0.0
    property bool switcherOpen: false
    property bool appDrawerOpen: false
    property bool powerMenuOpen: false

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

    // Heartbeat for dock population
    Timer {
        interval: 200
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
        id: connectWifiProc
        running: false
    }

    function connectWifi(ssid, password) {
        if (password && password !== "") {
            connectWifiProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password];
        } else {
            connectWifiProc.command = ["nmcli", "device", "wifi", "connect", ssid];
        }
        connectWifiProc.running = true;
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

    // ── Caffeine ──
    property bool caffeineActive: false
    Process { id: caffeineProc; running: false }

    function setCaffeine(active) {
        shellRoot.caffeineActive = active;
        if (active) {
            caffeineProc.command = ["pkill", "-STOP", "hypridle"];
        } else {
            caffeineProc.command = ["pkill", "-CONT", "hypridle"];
        }
        caffeineProc.running = true;
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

            let aOpt = audioOptions[audioIndex]
            let aStr = aOpt !== "none" ? `-a "${aOpt}"` : ""
            let cmd = `gpu-screen-recorder -w screen ${aStr} -f ${fpsOptions[fpsIndex]} -k ${encoderOptions[encoderIndex]} -s ${resOptions[resIndex]} -q ${bitrateOptions[bitrateIndex]} -o ~/Videos/ScreenRecord-$(date +%Y%m%d-%H%M%S).mp4`

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
            "battery-full-symbolic":               "file:///usr/share/icons/breeze-dark/status/24/battery-full-symbolic.svg",
            "battery-good-symbolic":               "file:///usr/share/icons/breeze-dark/status/24/battery-good-symbolic.svg",
            "battery-low-symbolic":                "file:///usr/share/icons/breeze-dark/status/24/battery-low-symbolic.svg",
            "battery-charging-symbolic":           "file:///usr/share/icons/breeze-dark/status/24/battery-080-charging-symbolic.svg",
            "battery-missing-symbolic":            "file:///usr/share/icons/breeze-dark/status/24/battery-missing-symbolic.svg",
            "window-close-symbolic":               "file:///usr/share/icons/breeze-dark/actions/24/window-close-symbolic.svg",
            "view-app-grid-symbolic":              "file:///usr/share/icons/breeze-dark/actions/24/view-grid-symbolic.svg",
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
            let isEnabled = (enabled === "true" || enabled === "1" || enabled === true);
            shellRoot.usePrecomputedBlur = isEnabled;
            if (isEnabled && shellRoot.wallpaperPath !== "") blurGenerator.startBlur();
        }

        function setBlurEnabled(enabled: string) {
            let isEnabled = (enabled === "true" || enabled === "1" || enabled === true);
            shellRoot.blurEnabled = isEnabled;
        }

        function setMaterial(material: string) {
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
            shellRoot.powerMenuOpen = true;
        }
        function hide() {
            shellRoot.powerMenuOpen = false;
        }
        function toggle() {
            shellRoot.powerMenuOpen = !shellRoot.powerMenuOpen;
        }
    }

    IpcHandler {
        target: "quicksettings"
        function show() {
            shellRoot.panelOpen = true;
        }
        function hide() {
            shellRoot.panelOpen = false;
        }
        function toggle() {
            shellRoot.panelOpen = !shellRoot.panelOpen;
        }
    }

    // ── UI Components ──
    BottomBar {}
    StatusBar {
        batteryPct: shellRoot.batteryPct
        batteryStatus: shellRoot.batteryStatus
    }
    QuickSettings {
        batteryPct: shellRoot.batteryPct
        batteryStatus: shellRoot.batteryStatus
    }
    NotificationPopup { id: globalToast }
    TaskManager {}
    AppDrawer {}
    VolumeOSD {}
    PowerMenu {}
}
