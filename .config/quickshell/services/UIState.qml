pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// UIState singleton — pure UI state and derived window-tracking properties.
// No Process/CLI plumbing; just flags and a context-menu registry.
//
// Owns:
//   - Panel visibility flags: panelOpen, panelDragOffset,
//     powerMenuOpen, appDrawerOpen, switcherOpen
//   - Dock state machine: barState ("handle" / "dock" / "overlay")
//   - Hyprland-derived: hasWindowsOnCurrentWs, hasSingleTiledWindow
//   - Per-screen context menu registry + open/close helpers

QtObject {
    id: uiState

    // ── Panel visibility ──
    property bool panelOpen: false
    property real panelDragOffset: 0.0
    property bool powerMenuOpen: false
    property bool appDrawerOpen: false
    property bool switcherOpen: false

    function closeOtherOverlays(except) {
        if (except !== "panel") panelOpen = false;
        if (except !== "power") powerMenuOpen = false;
        if (except !== "drawer") appDrawerOpen = false;
        if (except !== "switcher") switcherOpen = false;
    }

    // ── Dock state machine ──
    // Written by BottomBar.qml's gesture and lock timers; read by
    // BackgroundBar.qml for the dim trigger.
    property string barState: "handle"

    // ── Hyprland-derived properties ──
    // True when the focused workspace has any window that overlaps the
    // bottom dock hot-zone, or any non-floating window.
    property bool hasWindowsOnCurrentWs: {
        const ws = Hyprland.focusedWorkspace;
        if (!ws) return false;

        const toplevels = ws.toplevels.values;
        if (toplevels.length === 0) return false;

        let hasNonFloating = false;
        let anyOverlap = false;

        const dockHeight = 112;

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

            const isFloating = (tl.floating !== undefined) ? tl.floating : !!ipc.floating;

            if (!isFloating) {
                hasNonFloating = true;
                break;
            } else {
                const y = (ipc.at && ipc.at.length > 1) ? ipc.at[1] : 0;
                const h = (ipc.size && ipc.size.length > 1) ? ipc.size[1] : 0;
                const windowBottom = y + h;
                const hotZoneStart = monitorBottom - dockHeight - 5;

                if (windowBottom > hotZoneStart) {
                    anyOverlap = true;
                    break;
                }
            }
        }

        return hasNonFloating || anyOverlap;
    }

    // True when the focused workspace has exactly one tiled (non-floating)
    // window. Drives BackgroundBar.qml's dim layer.
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

    // ── Context menu registry (per-screen) ──
    property var _contextMenus: ({})

    function openContextMenuAtCursor(screen, model) {
        closeContextMenu(screen);

        let cursor = Hyprland.cursorPosition;
        let x = cursor ? cursor.x : (screen ? screen.x + screen.width / 2 : 0);
        let y = cursor ? cursor.y : (screen ? screen.y + screen.height / 2 : 0);

        let menuComponent = Qt.createComponent("../components/reusables/ContextMenu.qml");
        if (menuComponent.status === Component.Ready) {
            let menuWindow = menuComponent.createObject(uiState, {
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
                console.error("[UIState] Failed to create context menu:", menuComponent.errorString());
            }
        } else {
            console.error("[UIState] Failed to load ContextMenu.qml:", menuComponent.errorString());
        }
    }

    function closeContextMenu(screen) {
        let key = screen ? screen.name : "default";
        if (_contextMenus[key]) {
            _contextMenus[key].close();
            delete _contextMenus[key];
        }
    }

    function closeAllContextMenus() {
        for (let key in _contextMenus) {
            if (_contextMenus[key]) {
                _contextMenus[key].close();
            }
        }
        _contextMenus = ({});
    }
}
