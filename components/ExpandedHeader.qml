import QtQuick
import QtQuick.Layouts

// ExpandedHeader.qml — Reusable header for expanded toggle views.
//
// Usage (minimal):
//   ExpandedHeader {
//       title: "Wi-Fi"
//       subtitle: "Connected"
//       iconSource: root.iconSource
//       isActive: root.isActive
//       activeColor: root.activeColor
//   }
//
// Usage (with switch toggle):
//   ExpandedHeader {
//       title: "Wi-Fi"
//       subtitle: root.isActive ? "Connected" : "Off"
//       iconSource: root.iconSource
//       isActive: root.isActive
//       activeColor: root.activeColor
//       showSwitch: true
//       onSwitchToggled: root.toggled()
//   }
//
// Usage (with extra trailing content, e.g. a refresh button):
//   ExpandedHeader {
//       title: "Wi-Fi"
//       subtitle: "Connected"
//       iconSource: root.iconSource
//       isActive: root.isActive
//       activeColor: root.activeColor
//       showSwitch: true
//       onSwitchToggled: root.toggled()
//       trailingContent: Rectangle { /* your custom button */ }
//   }

ColumnLayout {
    id: header
    spacing: 16

    // ── Required properties ──
    property string title: ""
    property string subtitle: ""
    property string iconSource: ""
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)

    // ── Optional: Material 3 switch ──
    property bool showSwitch: false
    signal switchToggled()

    // ── Optional: extra content before the switch (e.g. refresh button) ──
    property alias trailingContent: trailingSlot.data

    RowLayout {
        Layout.fillWidth: true
        spacing: 16

        // Icon badge
        Rectangle {
            width: 48; height: 48; radius: 24
            color: header.isActive ? header.activeColor : Qt.rgba(1, 1, 1, 0.1)
            Behavior on color { ColorAnimation { duration: 200 } }
            Image {
                anchors.centerIn: parent
                sourceSize: Qt.size(24, 24)
                source: header.iconSource
            }
        }

        // Title + subtitle
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: header.title
                color: "white"
                font.pixelSize: 20
                font.bold: true
            }
            Text {
                text: header.subtitle
                color: Qt.rgba(1, 1, 1, 0.6)
                font.pixelSize: 14
                visible: text !== ""
            }
        }

        // Trailing slot (for custom buttons like refresh)
        Item {
            id: trailingSlot
            visible: children.length > 0
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            Layout.alignment: Qt.AlignVCenter
        }

        // Material 3 Switch
        Item {
            visible: header.showSwitch
            width: 52; height: 32
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: header.isActive ? header.activeColor : "transparent"
                border.width: header.isActive ? 0 : 2
                border.color: Qt.rgba(1, 1, 1, 0.4)
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
                onClicked: header.switchToggled()
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
