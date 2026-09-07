pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.DesktopEntries
import QtQuick

// ConfigStore — single source of truth for user-config persisted to config/config.json.
// Owns pinnedApps, toggleData, controlCenterLayout, mediaPlayerId and the
// functions that mutate them. Dock refresh is delegated to Dock.refreshDock().

QtObject {
    id: configStore

    // ── Persisted state ──
    property var pinnedApps: []
    property var runningAppIds: []
    property var toggleData: ({})
    property bool toggleDataLoaded: false
    property var controlCenterLayout: []
    property string mediaPlayerId: ""
    property bool configLoadComplete: false
    property bool _loadingConfig: false

    // ── Appearance state — also lives here for read-side ownership ──
    // Wallpapers singleton mutates these via loadConfig / saveConfig.
    // Properties are declared here so reads from any consumer reach
    // the same instance through the ConfigStore.qml singleton.
    // (Wallpapers re-exports them via its own property bindings.)

    // ── Load / Save plumbing ──
    Process {
        id: loadConfigProc
        command: ["cat", Qt.resolvedUrl("../config/config.json").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                configStore._loadingConfig = true;
                console.log("[Config] Raw:", text);
                try {
                    let cfg = JSON.parse(text) || {};
                    console.log("[Config] Parsed:", JSON.stringify(cfg));

                    if (cfg.pinnedApps) configStore.pinnedApps = cfg.pinnedApps;
                    if (cfg.toggleData) {
                        configStore.toggleData = cfg.toggleData;
                        Notifications.dndActive = !!cfg.toggleData["DndToggle"]?.active;
                    }
                    configStore.toggleDataLoaded = true;

                    let app = cfg.appearance || {};
                    if (app.materialTheme !== undefined) Wallpapers.materialTheme = app.materialTheme;
                    if (app.staticBlurEnabled !== undefined) Wallpapers.staticBlurEnabled = app.staticBlurEnabled;
                    if (app.blurEnabled !== undefined) Wallpapers.blurEnabled = app.blurEnabled;
                    if (app.accentColor !== undefined && app.accentColor !== null && app.accentColor !== "") {
                        let c = app.accentColor;
                        if (typeof c === "string" && c.startsWith("#")) {
                            let hex = c.slice(1);
                            if (/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(hex)) {
                                let r = Math.round(parseInt(hex.slice(0, 2), 16) / 255 * 255) / 255;
                                let g = Math.round(parseInt(hex.slice(2, 4), 16) / 255 * 255) / 255;
                                let b = Math.round(parseInt(hex.slice(4, 6), 16) / 255 * 255) / 255;
                                let a = hex.length === 8 ? Math.round(parseInt(hex.slice(6, 8), 16) / 255 * 255) / 255 : 1.0;
                                if (!isNaN(r) && !isNaN(g) && !isNaN(b) && !isNaN(a)) {
                                    Wallpapers.accentColor = Qt.rgba(r, g, b, a);
                                }
                            }
                        } else {
                            Wallpapers.accentColor = c;
                        }
                    }
                    if (app.wallpaperPath !== undefined) Wallpapers.wallpaperPath = app.wallpaperPath;

                    if (cfg.layout && cfg.layout.length > 0) configStore.controlCenterLayout = cfg.layout;
                    if (cfg.mediaPlayerId) configStore.mediaPlayerId = cfg.mediaPlayerId;
                    console.log("[Config] Layout:", JSON.stringify(configStore.controlCenterLayout));

                    Dock.refreshDock();
                    configStore.configLoadComplete = true;
                    console.log("[Config] Loaded successfully");
                } catch (e) {
                    console.error("Config load error:", e);
                    configStore.configLoadComplete = true;
                }
                configStore._loadingConfig = false;
            }
        }
    }

    FileView {
        path: Qt.resolvedUrl("../config/config.json").toString().replace("file://", "")
        watchChanges: true
        onFileChanged: {
            if (!loadConfigProc.running) loadConfigProc.running = true
        }
    }

    Process { id: saveConfigProc; running: false }

    function saveConfig() {
        if (!configStore.configLoadComplete || configStore._loadingConfig) return;
        let accentColorHex = null;
        if (Wallpapers.accentColor) {
            let c = Wallpapers.accentColor;
            let r = Math.round(c.r * 255).toString(16).padStart(2, '0');
            let g = Math.round(c.g * 255).toString(16).padStart(2, '0');
            let b = Math.round(c.b * 255).toString(16).padStart(2, '0');
            let a = Math.round(c.a * 255).toString(16).padStart(2, '0');
            accentColorHex = "#" + r + g + b + (a !== "ff" ? a : "");
        }
        let cfg = {
            pinnedApps: configStore.pinnedApps,
            toggleData: configStore.toggleData,
            appearance: {
                materialTheme: Wallpapers.materialTheme,
                staticBlurEnabled: Wallpapers.staticBlurEnabled,
                blurEnabled: Wallpapers.blurEnabled,
                accentColor: accentColorHex,
                wallpaperPath: Wallpapers.wallpaperPath || ""
            },
            layout: configStore.controlCenterLayout,
            mediaPlayerId: configStore.mediaPlayerId
        };
        let path = Qt.resolvedUrl("../config/config.json").toString().replace("file://", "");
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
            if (toIdx === -1) copy.push(fid);
            else copy.splice(toIdx, 0, fid);
        } else if (fromIdx !== toIdx) {
            let item = copy.splice(fromIdx, 1)[0];
            let adjustedToIdx = toIdx === -1 ? -1 : (toIdx > fromIdx ? toIdx - 1 : toIdx);
            if (adjustedToIdx === -1) {
                copy.push(item);
            } else {
                copy.splice(adjustedToIdx, 0, item);
            }
        }

        pinnedApps = copy.filter((v, i, a) => a.indexOf(v) === i);
        savePinnedApps();
        Dock.refreshDock();
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
        pinnedApps = copy;
        savePinnedApps();
        Dock.refreshDock();
    }
}
