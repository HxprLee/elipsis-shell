import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Bluetooth
import ".."

// BluetoothToggle.qml — Bluetooth toggle (data-only, styled by the shell).

Item {
    id: root
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Bluetooth"
    property string subtitleText: qs.bluetoothEnabled ? (shellRoot.bluetoothConnected ? shellRoot.bluetoothDeviceName : "On") : "Off"
    property string iconSource: shellRoot.icon(qs.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
    property bool isActive: qs.bluetoothEnabled
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    
    // Expanded view support
    property bool hasExpandedView: true
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot

            Component.onCompleted: {
                if (root.isActive) {
                    shellRoot.startBluetoothDiscovery()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 16

                // Header
                ExpandedHeader {
                    Layout.fillWidth: true
                    toggle: root
                    showSwitch: true
                    onSwitchToggled: root.toggled()
                }

                // Scrollable Content
                Flickable {
                    id: scrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: contentLayout.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar { }

                    ColumnLayout {
                        id: contentLayout
                        width: scrollView.width
                        spacing: 12

                        // --- Paired Devices Section ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            visible: pairedRepeater.count > 0

                            Text {
                                text: "Paired Devices"
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 12
                                font.bold: true
                                Layout.leftMargin: 4
                            }

                            Repeater {
                                id: pairedRepeater
                                model: Bluetooth.devices ? Bluetooth.devices.values.filter(d => d.paired && d.name && d.name !== "" && !/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/.test(d.name)) : []
                                delegate: deviceDelegateComponent
                            }
                        }

                        // --- Available Devices Section ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            visible: root.isActive

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Available Devices"
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                Item {
                                    id: refreshBtn
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: refreshRow.implicitWidth
                                    height: 24
                                    
                                    property bool isScanning: !!(Bluetooth.adapter && Bluetooth.adapter.discovering) || shellRoot.bluetoothScanningManual

                                    Row {
                                        id: refreshRow
                                        anchors.fill: parent
                                        spacing: 6

                                        Text {
                                            visible: !refreshBtn.isScanning
                                            text: "Refresh"
                                            color: refreshMouse.containsMouse ? root.activeColor : Qt.rgba(1, 1, 1, 0.4)
                                            font.pixelSize: 12
                                            font.bold: true
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }

                                        Image {
                                            visible: refreshBtn.isScanning
                                            sourceSize: Qt.size(16, 16)
                                            source: shellRoot.icon("view-refresh-symbolic")
                                            opacity: 0.6
                                            RotationAnimation on rotation {
                                                running: refreshBtn.isScanning
                                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: refreshMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            shellRoot.startBluetoothDiscovery()
                                        }
                                    }
                                }
                            }

                            Repeater {
                                id: availableRepeater
                                model: Bluetooth.devices ? Bluetooth.devices.values.filter(d => !d.paired && d.name && d.name !== "" && !/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/.test(d.name)) : []
                                delegate: deviceDelegateComponent
                            }

                            Text {
                                visible: availableRepeater.count === 0 && root.isActive && !refreshBtn.isScanning
                                text: "No devices found"
                                color: Qt.rgba(1, 1, 1, 0.3)
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 20
                            }
                        }
                    }
                }
            }

            // Define the delegate as a reusable component
            Component {
                id: deviceDelegateComponent
                Rectangle {
                    id: delegateRoot
                    Layout.fillWidth: true
                    height: modelData.connected ? 40 : 30
                    radius: 12
                    color: deviceArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    clip: true

                    ColumnLayout {
                        id: contentColumn
                        anchors.fill: parent
                        spacing: 0

                        // Top Row (Always Visible)
                        RowLayout {
                            id: mainRow
                            Layout.fillWidth: true
                            Layout.preferredHeight: modelData.connected ? 40 : 30
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            spacing: 10

                            Image {
                                Layout.alignment: Qt.AlignVCenter
                                sourceSize: Qt.size(20, 20)
                                source: shellRoot.icon("bluetooth-active-symbolic")
                                opacity: modelData.connected ? 1.0 : 0.6
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: modelData.name || modelData.alias || "Unknown Device"
                                    color: "white"
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: modelData.connected
                                    text: "Connected"
                                    color: root.activeColor
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                }
                            }

                            Image {
                                visible: modelData.connected
                                Layout.alignment: Qt.AlignVCenter
                                sourceSize: Qt.size(16, 16)
                                source: shellRoot.icon("object-select-symbolic")
                            }
                        }
                    }

                    MouseArea {
                        id: deviceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.connected) {
                                modelData.disconnect()
                            } else {
                                modelData.connect()
                            }
                        }
                    }
                }
            }
        }
    }

    signal toggled()
    onToggled: qs.toggleBluetooth()
}
