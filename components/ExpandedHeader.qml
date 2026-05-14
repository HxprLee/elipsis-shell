import QtQuick
import QtQuick.Layouts

// ExpandedHeader.qml — Reusable header for expanded toggle views.
//
// Usage (with toggle reference — preferred, reads properties automatically):
//   ExpandedHeader {
//       toggle: root
//       showSwitch: true
//       onSwitchToggled: root.toggled()
//   }
//
// Usage (manual — still supported, overrides toggle properties):
//   ExpandedHeader {
//       title: "Wi-Fi"
//       subtitle: "Connected"
//       iconSource: root.iconSource
//       isActive: root.isActive
//       activeColor: root.activeColor
//   }

ColumnLayout {
    id: header
    spacing: 16

    // ── Toggle reference (auto-reads properties) ──
    property var toggle: null

    // ── Properties — auto-read from toggle if set, overridable ──
    property string title: toggle ? (toggle.titleText !== undefined ? toggle.titleText : (toggle.toggleName || "")) : ""
    property string subtitle: toggle ? (toggle.subtitleText || "") : ""
    property string iconSource: toggle ? (toggle.iconSource || "") : ""
    property bool isActive: toggle ? !!toggle.isActive : false
    property color activeColor: toggle ? (toggle.activeColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)) : Qt.rgba(0.2, 0.5, 1.0, 1.0)

    // ── Optional: Material 3 switch ──
    property bool showSwitch: false
    signal switchToggled()

    // ── Optional: Button toggle ──
    property bool showButton: false
    property string buttonText: ""
    property string buttonIconSource: ""
    property bool isButtonActive: false
    property color buttonActiveColor: header.activeColor
    signal buttonClicked()

    // ── Optional: extra content before the switch (e.g. refresh button) ──
    property alias trailingContent: trailingSlot.data

    Item {
        Layout.fillWidth: true
        height: Math.max(iconBadge.height, titles.implicitHeight, switchItem.height, buttonItem.height, trailingSlot.implicitHeight)

        // Icon badge
        Rectangle {
            id: iconBadge
            width: 48; height: 48; radius: 24
            color: header.isActive ? header.activeColor : Qt.rgba(1, 1, 1, 0.1)
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
            Image {
                anchors.centerIn: parent
                sourceSize: Qt.size(24, 24)
                source: header.iconSource
            }
        }

        // Title + subtitle
        ColumnLayout {
            id: titles
            anchors.left: iconBadge.right
            anchors.leftMargin: 16
            anchors.right: trailingSlot.visible ? trailingSlot.left : (header.showSwitch ? switchItem.left : (header.showButton ? buttonItem.left : parent.right))
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: header.title
                color: "white"
                font.pixelSize: 20
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: header.subtitle
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 14
                visible: text !== ""
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Trailing slot (for custom buttons like refresh)
        Item {
            id: trailingSlot
            visible: children.length > 0
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            anchors.right: header.showSwitch ? switchItem.left : (header.showButton ? buttonItem.left : parent.right)
            anchors.rightMargin: (header.showSwitch || header.showButton) ? 16 : 0
            anchors.verticalCenter: parent.verticalCenter
        }

        // Material 3 Switch
        Item {
            id: switchItem
            visible: header.showSwitch
            width: header.showSwitch ? 52 : 0
            height: 32
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: header.isActive ? header.activeColor : "transparent"
                border.width: header.isActive ? 0 : 2
                border.color: Qt.rgba(1, 1, 1, 0.4)
                visible: header.showSwitch
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on border.width { NumberAnimation { duration: 200 } }
            }

            Rectangle {
                width: header.isActive ? 24 : 16
                height: width
                radius: width / 2
                color: header.isActive ? "white" : Qt.rgba(1, 1, 1, 0.6)
                y: (parent.height - height) / 2
                x: header.isActive ? (parent.width - width - 4) : 4
                visible: header.showSwitch
                Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 200 } }
                scale: m3Area.pressed ? 0.9 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                id: m3Area
                anchors.fill: parent
                anchors.margins: -4
                enabled: header.showSwitch
                onClicked: header.switchToggled()
            }
        }

        // Button Toggle
        Item {
            id: buttonItem
            visible: header.showButton && !header.showSwitch
            width: visible ? buttonRect.width : 0
            height: 36
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: buttonRect
                height: 36
                width: buttonLayout.implicitWidth + 24
                radius: 18
                color: header.isButtonActive ? header.buttonActiveColor : Qt.rgba(1, 1, 1, 0.1)
                border.width: header.isButtonActive ? 0 : 1
                border.color: header.isButtonActive ? "transparent" : Qt.rgba(1, 1, 1, 0.2)
                Behavior on color { ColorAnimation { duration: 200 } }

                RowLayout {
                    id: buttonLayout
                    anchors.centerIn: parent
                    spacing: 6

                    Image {
                        source: header.buttonIconSource
                        sourceSize: Qt.size(16, 16)
                        visible: header.buttonIconSource !== ""
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Text {
                        text: header.buttonText
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                        visible: header.buttonText !== ""
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = header.isButtonActive ? Qt.lighter(header.buttonActiveColor, 1.1) : Qt.rgba(1, 1, 1, 0.15)
                    onExited: parent.color = header.isButtonActive ? header.buttonActiveColor : Qt.rgba(1, 1, 1, 0.1)
                    onClicked: header.buttonClicked()
                }
            }
        }
    }

    // Divider
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(1, 1, 1, 0.1)
    }
}
