import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

// PowerMenu.qml — Full-screen power menu overlay.
// Actions: Power Off, Restart, Suspend, Lock
// Triggered via PowerToggle or IPC: qs-ipc power show

PanelWindow {
    id: powerMenu
    visible: false
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.layer: WlrLayershell.Overlay

    WlrLayershell.keyboardFocus: powerMenu.visible ? WlrLayershell.OnDemand : WlrLayershell.None

    property bool isOpen: shellRoot.powerMenuOpen

    onIsOpenChanged: {
        if (isOpen) {
            powerMenu.visible = true
            showAnim.start()
        } else {
            hideAnim.start()
        }
    }

    // ── Show Animation ──
    SequentialAnimation {
        id: showAnim
        PropertyAction { target: overlay; property: "opacity"; value: 0 }
        PropertyAction { target: buttonContainer; property: "scale"; value: 0.8 }
        PropertyAction { target: buttonContainer; property: "opacity"; value: 0 }
        ParallelAnimation {
            NumberAnimation { target: overlay; property: "opacity"; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: buttonContainer; property: "scale"; to: 1.0; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            NumberAnimation { target: buttonContainer; property: "opacity"; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
        }
    }

    // ── Hide Animation ──
    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation { target: overlay; property: "opacity"; to: 0; duration: 250; easing.type: Easing.InCubic }
            NumberAnimation { target: buttonContainer; property: "scale"; to: 0.8; duration: 250; easing.type: Easing.InCubic }
            NumberAnimation { target: buttonContainer; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        }
        PropertyAction { target: powerMenu; property: "visible"; value: false }
    }

    // ── Background overlay ──
    Rectangle {
        id: overlay
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.7)
        opacity: 0

        MouseArea {
            anchors.fill: parent
            onClicked: shellRoot.powerMenuOpen = false
        }
    }

    // ── Action Buttons ──
    Item {
        id: buttonContainer
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 400)
        height: buttonLayout.implicitHeight
        scale: 0.8
        opacity: 0

        ColumnLayout {
            id: buttonLayout
            anchors.fill: parent
            spacing: 16

            // Title
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 16
                text: "Power"
                color: "white"
                font.pixelSize: 28
                font.bold: true
            }

            // Power Off
            PowerMenuButton {
                Layout.fillWidth: true
                label: "Power Off"
                iconName: "system-shutdown-symbolic"
                buttonColor: Qt.rgba(0.9, 0.2, 0.2, 1.0)
                Accessible.name: "Power Off"
                Accessible.role: Accessible.Button
                onClicked: {
                    shellRoot.powerMenuOpen = false
                    powerOffProc.running = true
                }
            }

            // Restart
            PowerMenuButton {
                Layout.fillWidth: true
                label: "Restart"
                iconName: "system-reboot-symbolic"
                buttonColor: Qt.rgba(1.0, 0.6, 0.2, 1.0)
                Accessible.name: "Restart"
                Accessible.role: Accessible.Button
                onClicked: {
                    shellRoot.powerMenuOpen = false
                    restartProc.running = true
                }
            }

            // Suspend
            PowerMenuButton {
                Layout.fillWidth: true
                label: "Suspend"
                iconName: "system-suspend-symbolic"
                buttonColor: Qt.rgba(0.4, 0.5, 1.0, 1.0)
                Accessible.name: "Suspend"
                Accessible.role: Accessible.Button
                onClicked: {
                    shellRoot.powerMenuOpen = false
                    suspendProc.running = true
                }
            }

            // Lock
            PowerMenuButton {
                Layout.fillWidth: true
                label: "Lock"
                iconName: "system-lock-screen-symbolic"
                buttonColor: Qt.rgba(0.3, 0.7, 0.4, 1.0)
                Accessible.name: "Lock Screen"
                Accessible.role: Accessible.Button
                onClicked: {
                    shellRoot.powerMenuOpen = false
                    lockProc.running = true
                }
            }

            // Cancel
            Item { Layout.preferredHeight: 8 }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.1)
                Accessible.name: "Cancel"
                Accessible.role: Accessible.Button

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    color: "white"
                    font.pixelSize: 17
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: shellRoot.powerMenuOpen = false
                }
            }
        }
    }

    // ── Reusable button component ──
    component PowerMenuButton: Rectangle {
        property string label: ""
        property string iconName: ""
        property color buttonColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
        signal clicked()

        height: 72
        radius: 20
        color: buttonMouse.pressed ? Qt.darker(buttonColor, 1.2) : buttonColor
        Behavior on color { ColorAnimation { duration: 100 } }

        scale: buttonMouse.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 16

            Rectangle {
                width: 40; height: 40; radius: 20
                color: Qt.rgba(1, 1, 1, 0.2)

                Image {
                    anchors.centerIn: parent
                    sourceSize: Qt.size(22, 22)
                    source: shellRoot.icon(iconName)
                }
            }

            Text {
                Layout.fillWidth: true
                text: label
                color: "white"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            onClicked: parent.clicked()
        }
    }

    // ── System commands ──
    Process {
        id: powerOffProc
        command: ["systemctl", "poweroff"]
        running: false
    }
    Process {
        id: restartProc
        command: ["systemctl", "reboot"]
        running: false
    }
    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
        running: false
    }
    Process {
        id: lockProc
        command: ["loginctl", "lock-session"]
        running: false
    }

    // Dismiss on Escape
    Shortcut {
        sequence: "Escape"
        enabled: powerMenu.visible
        onActivated: shellRoot.powerMenuOpen = false
    }
}
