//@ pragma IconTheme breeze-dark

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "components"
import "services"

ShellRoot {
    id: shellRoot

    // All backend state lives in services/. shell.qml is now just composition:
    // IPC handlers delegate to services, Variants mount UI components, and
    // a Notifications→toast bridge wires the popup.

    IpcHandler {
        target: "lock"
        function toggle(): void { Lock.toggle(); }
        function lock(): void { Lock.lock(); }
        function unlock(): void { Lock.unlock(); }
    }

    // WlSessionLock needs import "components" to resolve Lockscreen.
    WlSessionLock {
        id: sessionLock
        locked: Lock.isLocked
        surface: Lockscreen {}
    }

    IpcHandler {
        target: "appearance"
        function setPrecomputedBlur(enabled: string): void { Wallpapers.setPrecomputedBlur(enabled); }
        function setBlurEnabled(enabled: string): void { Wallpapers.setBlurEnabled(enabled); }
        function setMaterial(material: string): void { Wallpapers.setMaterial(material); }
    }

    IpcHandler {
        target: "power"
        function show(): void { UIState.closeOtherOverlays("power"); UIState.powerMenuOpen = true; }
        function hide(): void { UIState.powerMenuOpen = false; }
        function toggle(): void {
            if (UIState.powerMenuOpen) UIState.powerMenuOpen = false;
            else { UIState.closeOtherOverlays("power"); UIState.powerMenuOpen = true; }
        }
    }

    IpcHandler {
        target: "quicksettings"
        function show(): void { UIState.closeOtherOverlays("panel"); UIState.panelOpen = true; }
        function hide(): void { UIState.panelOpen = false; }
        function toggle(): void {
            if (UIState.panelOpen) UIState.panelOpen = false;
            else { UIState.closeOtherOverlays("panel"); UIState.panelOpen = true; }
        }
    }

    IpcHandler {
        target: "task_manager"
        function toggle(): void {
            if (UIState.switcherOpen) UIState.switcherOpen = false;
            else { UIState.closeOtherOverlays("switcher"); UIState.switcherOpen = true; }
        }
        function open(): void { UIState.closeOtherOverlays("switcher"); UIState.switcherOpen = true; }
        function close(): void { UIState.switcherOpen = false; }
    }

    // Pipewire tracker (volume source/sink) lives here so VolumeOSD/VolumeSlider react.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
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
}
