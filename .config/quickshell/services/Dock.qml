pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick

// Dock singleton — owns the dockApps ListModel and refreshDock() logic.
// Pinned/running state is sourced from ConfigStore.pinnedApps (already
// loaded by ConfigStore on startup). App-drawer consumers read
// ConfigStore.runningAppIds (updated here).
//
// Hyprland event listeners and the heartbeat timer live here too.

Item {
    id: dock

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
                windowCounts[entry.id] = (windowCounts[entry.id] || 0) + 1;
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
                        windowCount: 0,
                        isFocused: false
                    });
                    addedIds.add(entry.id);
                }
            }
        }

        for (let app of runningApps) {
            app.windowCount = Math.min(windowCounts[app.id] || 1, 5);
            app.isFocused = (app.id === focusedEntryId);
        }

        // Update reactive running state for App Drawer.
        ConfigStore.runningAppIds = runningIdsList;

        let targetApps = [];
        let pinnedAdded = new Set();

        // 2. Build target list: Pinned first.
        for (let pid of ConfigStore.pinnedApps) {
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

        // 4. Incrementally update the ListModel
        for (let i = dockApps.count - 1; i >= 0; i--) {
            let item = dockApps.get(i);
            if (!targetApps.find(a => a.id === item.id)) {
                dockApps.remove(i);
            }
        }

        for (let i = 0; i < targetApps.length; i++) {
            let target = targetApps[i];

            if (i < dockApps.count && dockApps.get(i).id === target.id) {
                let existing = dockApps.get(i);
                if (existing.isRunning !== target.isRunning || existing.address !== target.address || existing.isPinned !== target.isPinned || existing.windowCount !== target.windowCount || existing.isFocused !== target.isFocused) {
                    dockApps.setProperty(i, "isRunning", target.isRunning);
                    dockApps.setProperty(i, "address", target.address);
                    dockApps.setProperty(i, "isPinned", target.isPinned);
                    dockApps.setProperty(i, "windowCount", target.windowCount);
                    dockApps.setProperty(i, "isFocused", target.isFocused);
                }
            } else {
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
        function onValuesChanged() { dock.refreshDock(); }
    }

    // Direct event connection for instant updates
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            let name = event.name;
            if (name === "openwindow" || name === "closewindow" || name === "movewindow" || name === "resizewindow" || name === "fullscreen" || name === "activewindow2" || name === "windowtitle") {
                Hyprland.refreshToplevels();
                dock.refreshDock();
            }
        }
    }

    // Heartbeat for dock population (belt-and-suspenders on top of event listeners).
    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            Hyprland.refreshToplevels();
            dock.refreshDock();
        }
    }
}
