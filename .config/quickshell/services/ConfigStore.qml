pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// ConfigStore — single source of truth for user-config persisted to config/config.json.
// Owns pinnedApps, toggleData, controlCenterPages, mediaPlayerId and the
// functions that mutate them. Dock refresh is delegated to Dock.refreshDock().

Item {
    id: configStore

    // ── Persisted state ──
    property var pinnedApps: []
    property var runningAppIds: []
    property var toggleData: ({})
    property bool toggleDataLoaded: false
    // Paginated control-center layout. Each element is a page = an ordered
    // array of {source, colSpan, rowSpan} entries, capped at a 4x8 grid.
    // Empty array means "no saved pages" — the consumer falls back to its
    // built-in default. Replaces the flat `layout` key; see loadConfigProc
    // for the one-way migration from legacy `layout`.
    property var controlCenterPages: []
    property string mediaPlayerId: ""
    property bool configLoadComplete: false
    property bool _loadingConfig: false

    // ── Load / Save plumbing ──
    Process {
        id: loadConfigProc
        command: ["cat", Qt.resolvedUrl("../config/config.json").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                configStore._loadingConfig = true;
                console.debug("[Config] Raw:", text);
                try {
                    let cfg = JSON.parse(text) || {};
                    console.debug("[Config] Parsed:", JSON.stringify(cfg));

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

                    // Paginated layout wins when present. Otherwise migrate the
                    // legacy flat `layout` array by wrapping it as a single
                    // page, so an existing config is never silently dropped.
                    // The wrapper is only persisted back on the next save.
                    if (cfg.pages && Array.isArray(cfg.pages) && cfg.pages.length > 0) {
                        configStore.controlCenterPages = cfg.pages;
                    } else if (cfg.layout && cfg.layout.length > 0) {
                        configStore.controlCenterPages = [cfg.layout];
                        console.debug("[Config] Migrated legacy flat layout to single page");
                    } else {
                        configStore.controlCenterPages = [];
                    }
                    if (cfg.mediaPlayerId) configStore.mediaPlayerId = cfg.mediaPlayerId;
                    console.debug("[Config] Pages:", JSON.stringify(configStore.controlCenterPages));

                    Dock.refreshDock();
                    configStore.configLoadComplete = true;
                    console.debug("[Config] Loaded successfully");
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

    // Debounces the config.json write. Every control-center edit (resize, move,
    // add, remove) calls saveLayout() -> saveConfig(), and each write shells
    // out AND trips the FileView watcher, which re-reads and re-parses the
    // whole file. During a drag or a run of resizes that is dozens of redundant
    // round-trips. Coalescing them into one write keeps the UI responsive.
    Timer {
        id: saveConfigDebounce
        interval: 600
        repeat: false
        onTriggered: configStore._writeConfig()
    }

    // A write is pending if the debounce timer is running. Exposed so shutdown
    // can flush it — otherwise the last edit before quitting is lost.
    readonly property bool savePending: saveConfigDebounce.running

    // Schedules a write. Cheap to call repeatedly — each call just restarts
    // the timer, so a burst of edits lands as a single write.
    function saveConfig() {
        if (!configStore.configLoadComplete || configStore._loadingConfig) return;
        saveConfigDebounce.restart();
    }

    function _writeConfig() {
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
            pages: configStore.controlCenterPages,
            mediaPlayerId: configStore.mediaPlayerId
        };
        let path = Qt.resolvedUrl("../config/config.json").toString().replace("file://", "");
        saveConfigProc.command = ["sh", "-c", "echo \"$1\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"", "sh", JSON.stringify(cfg, null, 2), path];
        saveConfigProc.running = true;
    }

    function flushSave() {
        // Writes any debounced save immediately. Call before anything that can end
        // the process (power off, reboot, quit) so the final edit isn't lost.
        if (!configStore.savePending) return;
        saveConfigDebounce.stop();
        configStore._writeConfig();
    }

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
        saveConfig();
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
        saveConfig();
        Dock.refreshDock();
    }
}
