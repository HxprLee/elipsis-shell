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
                Rectangle {
                    property int wsId: index + 1
                    property bool isActive: Hyprland.focusedMonitor
                                            ? (Hyprland.focusedMonitor.activeWorkspace
                                               ? Hyprland.focusedMonitor.activeWorkspace.id === wsId
                                               : false)
                                            : false
                    property bool wsExists: {
                        if (isActive) return true;
                        for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                            if (Hyprland.workspaces.values[i].id === wsId) return true;
                        }
                        return false;
                    }

                    visible: wsExists
                    width: isActive ? 36 : 24
                    height: 20
                    radius: 10
                    color: isActive ? statusBar.contentColor : "transparent"
                    border.color: statusBar.contentColor
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Text {
                        anchors.centerIn: parent
                        text: wsId
                        color: parent.isActive ? (statusBar.contentColor.r + statusBar.contentColor.g + statusBar.contentColor.b < 1.5 ? "white" : "black") : statusBar.contentColor
                        font.pixelSize: 12
                        font.bold: true
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch("workspace " + wsId)
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
