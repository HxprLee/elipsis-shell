import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: statusBar
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 40
    exclusionMode: ExclusionMode.Auto

    // ── Single Tiled Window Detection ──
    property bool hasSingleTiledWindow: {
        let ws = Hyprland.focusedMonitor?.activeWorkspace;
        if (!ws) return false;
        let toplevels = Hyprland.toplevels?.values;
        if (!toplevels) return false;
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

    // ── Background ──
    Rectangle {
        id: statusBarBg
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        opacity: hasSingleTiledWindow ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // Override color when blurEnabled is false
    Binding on color {
        when: !shellRoot.blurEnabled
        value: Qt.rgba(0, 0, 0, 0.3)
    }

    // ── Battery ──
    property int batteryPct: -1
    property string batteryStatus: ""

    property string currentTime: Qt.formatDateTime(new Date(), "HH:mm")

    // ── Dynamic Coloring ──
    ScreencopyView {
        id: screencopy
        captureSource: statusBar.screen
        visible: false
    }

    ShaderEffectSource {
        id: sampleArea
        sourceItem: screencopy
        sourceRect: Qt.rect(0, 0, statusBar.width, statusBar.height)
        live: false
        hideSource: true
        visible: false
    }

    ColorQuantizer { id: quantizer; depth: 2 }

    property color contentColor: "white"

Timer {
    interval: 3000 // Sample every 3s to balance performance
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
        statusBar.currentTime = Qt.formatDateTime(new Date(), "HH:mm")

        /*
        if (statusBar.screen && screencopy.hasContent) {
            screencopy.captureFrame();
            sampleArea.scheduleUpdate();
            sampleArea.grabToImage(result => {
                let path = "/tmp/qs_status_sample.png";
                result.saveToFile(path);
                quantizer.source = "file://" + path + "?t=" + Date.now();
            }, Qt.size(32, 10)); // Downsample for faster quantization
        }
        */
    }
}

// ── Left: time + workspaces ──
    Row {
        id: leftContent
        opacity: Math.max(0, 1.0 - (shellRoot.panelDragOffset / 40.0))
        visible: opacity > 0
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Text {
            text: statusBar.currentTime
            color: statusBar.contentColor
            font.pixelSize: 15
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: 9
                MaterialSurface {
                    property int wsId: index + 1
                    property bool isWsActive: Hyprland.focusedMonitor
                                            ? (Hyprland.focusedMonitor.activeWorkspace
                                               ? Hyprland.focusedMonitor.activeWorkspace.id === wsId
                                               : false)
                                            : false
                    property bool wsHasWindows: {
                        if (Hyprland.workspaces) {
                            for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                                if (Hyprland.workspaces.values[i].id === wsId) {
                                    let toplevels = Hyprland.workspaces.values[i].toplevels;
                                    return toplevels && toplevels.values && toplevels.values.length > 0;
                                }
                            }
                        }
                        return false;
                    }
                    visible: wsHasWindows || isWsActive

                    width: isWsActive ? 36 : 24
                    height: 20
                    radius: 10
                    isActive: isWsActive

                    Text {
                        anchors.centerIn: parent
                        text: wsId
                        color: isWsActive ? (statusBar.contentColor.r + statusBar.contentColor.g + statusBar.contentColor.b < 1.5 ? "white" : "black") : statusBar.contentColor
                        font.pixelSize: 12
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })")
                    }

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutExpo }
                    }
                }
            }
        }
    }

    // ── Right: status cluster ──
    StatusCluster {
        id: rightContent
        opacity: Math.max(0, 1.0 - (shellRoot.panelDragOffset / 40.0))
        visible: opacity > 0
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        color: statusBar.contentColor
        batteryPct: statusBar.batteryPct
        batteryStatus: statusBar.batteryStatus
    }

    // ── Swipe down anywhere → open QuickSettings panel ──
    MouseArea {
        anchors.fill: parent
        z: -1

        property real startY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            startY = mouse.y
            isDragging = false
        }
        onPositionChanged: (mouse) => {
            let dy = mouse.y - startY
            if (!shellRoot.panelOpen && dy > 10) {
                isDragging = true
                shellRoot.panelDragOffset = dy * 0.8
            }
        }
        onReleased: (mouse) => {
            if (isDragging) {
                if (shellRoot.panelDragOffset > 60) {
                    shellRoot.panelOpen = true
                }
                shellRoot.panelDragOffset = 0
                isDragging = false
            }
        }
    }
}
