import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Bluetooth
import ".."
import "../reusables"

// BluetoothToggle.qml — Bluetooth toggle (data-only, styled by the shell).

Item {
    id: root
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Bluetooth"
    property string titleText: {
        if (!qs.bluetoothEnabled) return "Bluetooth";
        let count = shellRoot.connectedBluetoothDevices.length;
        if (count === 1) return shellRoot.bluetoothDeviceName;
        return "Bluetooth";
    }
    property string subtitleText: {
        if (!qs.bluetoothEnabled) return "Off";
        let count = shellRoot.connectedBluetoothDevices.length;
        if (count === 1) return "Connected";
        if (count > 1) return count + " connected";
        return "On";
    }
    property string iconSource: shellRoot.icon(qs.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
    property bool isActive: qs.bluetoothEnabled
    property color activeColor: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
    
    // Expanded view support
    property bool hasExpandedView: true
    property int expandedHeight: 480
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot

            Component.onCompleted: {
                if (root.isActive) {
                    shellRoot.startBluetoothDiscovery()
                }
            }

            Component.onDestruction: {
                if (Bluetooth.adapter) {
                    Bluetooth.adapter.discovering = false;
                } else if (Bluetooth.adapters && Bluetooth.adapters.values && Bluetooth.adapters.values.length > 0) {
                    Bluetooth.adapters.values[0].discovering = false;
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
                    Layout.preferredHeight: contentLayout.implicitHeight
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
                ToggleListItem {
                    title: modelData.name || modelData.alias || "Unknown Device"
                    subtitle: modelData.connected ? "Connected" : ""
                    subtitleColor: root.activeColor
                    iconSource: shellRoot.icon("bluetooth-active-symbolic")
                    iconOpacity: modelData.connected ? 1.0 : 0.6
                    showCheckmark: modelData.connected
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

    signal toggled()
    onToggled: qs.toggleBluetooth()
}
