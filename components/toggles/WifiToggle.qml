import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

// WifiToggle.qml — WiFi toggle (data-only, styled by the shell).

Item {
    id: root
    property bool isSimpleToggle: true
    property string titleText: "WiFi"
    property string iconSource: shellRoot.icon(qs.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic")
    property bool isActive: qs.wifiEnabled
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    
    // Expanded view support
    property bool hasExpandedView: true
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot
            property var selectedNetwork: null

            // Enable wifi scanner while expanded view is open
            Binding {
                target: shellRoot.wifiDevice
                property: "scannerEnabled"
                value: root.isActive && expandedOverlay.isExpanded
                when: shellRoot.wifiDevice !== null
                restoreMode: Binding.RestoreBindingOrValue
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 16

                // Header
                ExpandedHeader {
                    Layout.fillWidth: true
                    title: "Wi-Fi"
                    subtitle: root.isActive ? (shellRoot.wifiSsid || "Connected") : "Off"
                    iconSource: root.iconSource
                    isActive: root.isActive
                    activeColor: root.activeColor
                    showSwitch: true
                    onSwitchToggled: root.toggled()

                    trailingContent: Rectangle {
                        width: 32; height: 32; radius: 16
                        color: Qt.rgba(1, 1, 1, 0.1)
                        visible: root.isActive
                        Image {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            sourceSize: Qt.size(24, 24)
                            source: shellRoot.icon("view-refresh-symbolic") || ""
                            RotationAnimation on rotation {
                                running: shellRoot.wifiDevice && shellRoot.wifiDevice.scannerEnabled
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (shellRoot.wifiDevice) shellRoot.wifiDevice.scannerEnabled = true
                        }
                    }
                }

                // Networks List
                ListView {
                    id: networkList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: shellRoot.wifiDevice ? shellRoot.wifiDevice.networks.values : []

                    delegate: Rectangle {
                        width: networkList.width
                        height: 56
                        radius: 16
                        color: modelData.connected ? Qt.rgba(1, 1, 1, 0.1) : (netArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 16

                            Image {
                                sourceSize: Qt.size(20, 20)
                                source: {
                                    if (modelData.signalStrength >= 0.8) return shellRoot.icon("network-wireless-signal-excellent-symbolic");
                                    if (modelData.signalStrength >= 0.6) return shellRoot.icon("network-wireless-signal-good-symbolic");
                                    if (modelData.signalStrength >= 0.4) return shellRoot.icon("network-wireless-signal-ok-symbolic");
                                    if (modelData.signalStrength >= 0.2) return shellRoot.icon("network-wireless-signal-weak-symbolic");
                                    return shellRoot.icon("network-wireless-signal-none-symbolic");
                                }
                            }

                            Text {
                                text: modelData.name || "Hidden Network"
                                color: "white"
                                font.pixelSize: 16
                                Layout.fillWidth: true
                            }

                            Image {
                                visible: modelData.connected
                                sourceSize: Qt.size(16, 16)
                                source: shellRoot.icon("object-select-symbolic") // checkmark
                            }
                        }

                        MouseArea {
                            id: netArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.connected) {
                                    modelData.disconnect()
                                } else {
                                    expandedRoot.selectedNetwork = modelData
                                    if (modelData.requiresPassword) {
                                        passwordPopup.visible = true
                                        passInput.focus = true
                                    } else {
                                        modelData.connect()
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.isActive
                        text: "Wi-Fi is Off"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 16
                    }
                }
            }

            // Password Prompt Overlay
            Rectangle {
                id: passwordPopup
                anchors.fill: parent
                color: Qt.rgba(0.05, 0.05, 0.1, 0.95)
                radius: 24
                visible: false

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 20

                    Text {
                        text: "Enter Password for\n" + (expandedRoot.selectedNetwork ? expandedRoot.selectedNetwork.name : "")
                        color: "white"
                        font.pixelSize: 18
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    TextField {
                        id: passInput
                        Layout.fillWidth: true
                        placeholderText: "Password"
                        echoMode: TextField.Password
                        color: "white"
                        background: Rectangle {
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.1)
                            border.color: passInput.activeFocus ? root.activeColor : "transparent"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Button {
                            text: "Cancel"
                            Layout.fillWidth: true
                            onClicked: {
                                passwordPopup.visible = false
                                passInput.text = ""
                            }
                        }

                        Button {
                            text: "Connect"
                            Layout.fillWidth: true
                            highlighted: true
                            onClicked: {
                                if (expandedRoot.selectedNetwork) {
                                    expandedRoot.selectedNetwork.connect(passInput.text)
                                }
                                passwordPopup.visible = false
                                passInput.text = ""
                            }
                        }
                    }
                }
            }
        }
    }

    signal toggled()
    onToggled: qs.toggleWifi()
}
