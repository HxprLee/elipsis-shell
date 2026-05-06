import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Networking
import ".."

// WifiToggle.qml — WiFi toggle (data-only, styled by the shell).

Item {
    id: root
    property bool isSimpleToggle: true
    property string titleText: "Wi-Fi"
    property string subtitleText: qs.wifiEnabled ? (shellRoot.wifiSsid || "Connected") : "Off"
    property string iconSource: shellRoot.icon(qs.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic")
    property bool isActive: qs.wifiEnabled
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    
    // Expanded view support
    property bool hasExpandedView: true
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot

            Component.onCompleted: {
                if (root.isActive) {
                    shellRoot.startWifiScan()
                }
            }
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

                        // --- Saved Networks Section ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            visible: savedRepeater.count > 0

                            Text {
                                text: "Saved Networks"
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 12
                                font.bold: true
                                Layout.leftMargin: 4
                            }

                            Repeater {
                                id: savedRepeater
                                model: shellRoot.wifiDevice ? shellRoot.wifiDevice.networks.values.filter(n => n.known) : []
                                delegate: networkDelegateComponent
                            }
                        }

                        // --- Available Networks Section ---
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
                                    text: "Available Networks"
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
                                    
                                    property bool isScanning: !!(shellRoot.wifiDevice && shellRoot.wifiDevice.scannerEnabled)

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
                                            shellRoot.startWifiScan()
                                        }
                                    }
                                }
                            }

                            Repeater {
                                id: availableRepeater
                                model: shellRoot.wifiDevice ? shellRoot.wifiDevice.networks.values.filter(n => !n.known) : []
                                delegate: networkDelegateComponent
                            }

                            Text {
                                visible: availableRepeater.count === 0 && root.isActive
                                text: "No networks found"
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
                id: networkDelegateComponent
                Rectangle {
                    id: delegateRoot
                    Layout.fillWidth: true
                    height: isExpanded ? implicitHeight : (modelData.connected ? 40 : 30)
                    implicitHeight: contentColumn.implicitHeight + 16
                    radius: 12
                    color: netArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    clip: true

                    Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }

                    property bool isExpanded: expandedRoot.selectedNetwork === modelData && !modelData.connected && modelData.security !== 0 && !modelData.known

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
                                source: {
                                    if (modelData.signalStrength >= 0.8) return shellRoot.icon("network-wireless-signal-excellent-symbolic");
                                    if (modelData.signalStrength >= 0.6) return shellRoot.icon("network-wireless-signal-good-symbolic");
                                    if (modelData.signalStrength >= 0.4) return shellRoot.icon("network-wireless-signal-ok-symbolic");
                                    if (modelData.signalStrength >= 0.2) return shellRoot.icon("network-wireless-signal-weak-symbolic");
                                    return shellRoot.icon("network-wireless-signal-none-symbolic");
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                Text {
                                    text: modelData.name || "Hidden Network"
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

                            Image {
                                visible: !modelData.connected && modelData.security !== 0
                                Layout.alignment: Qt.AlignVCenter
                                sourceSize: Qt.size(14, 14)
                                source: shellRoot.icon("system-lock-screen-symbolic")
                                opacity: 0.5
                            }
                        }

                        // Expanded Content (Password Input)
                        ColumnLayout {
                            id: expandedSection
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            Layout.bottomMargin: 12
                            visible: delegateRoot.isExpanded || opacity > 0
                            opacity: delegateRoot.isExpanded ? 1.0 : 0.0
                            spacing: 12
                            Behavior on opacity { NumberAnimation { duration: 200 } }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 48
                                radius: 12
                                color: Qt.rgba(1, 1, 1, 0.08)
                                border.color: passInput.activeFocus ? root.activeColor : Qt.rgba(1, 1, 1, 0.1)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 4
                                    TextField {
                                        id: passInput
                                        Layout.fillWidth: true
                                        placeholderText: "Password"
                                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.3)
                                        echoMode: showPassBtn.checked ? TextField.Normal : TextField.Password
                                        color: "white"
                                        font.pixelSize: 14
                                        background: null
                                        focus: delegateRoot.isExpanded
                                        onAccepted: connectBtn.clicked()
                                    }
                                    Button {
                                        id: showPassBtn
                                        width: 32; height: 32
                                        checkable: true
                                        flat: true
                                        contentItem: Text {
                                            text: showPassBtn.checked ? "👁️" : "👁️‍🗨️"
                                            font.pixelSize: 14
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            opacity: showPassBtn.checked ? 1.0 : 0.5
                                        }
                                        background: null
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Button {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    flat: true
                                    contentItem: Text {
                                        text: "Cancel"
                                        color: "white"
                                        font.pixelSize: 13
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        radius: 10
                                        color: parent.pressed ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                    }
                                    onClicked: expandedRoot.selectedNetwork = null
                                }
                                Button {
                                    id: connectBtn
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    contentItem: Text {
                                        text: "Connect"
                                        color: "white"
                                        font.pixelSize: 13
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    background: Rectangle {
                                        radius: 10
                                        color: parent.pressed ? Qt.darker(root.activeColor, 1.2) : root.activeColor
                                    }
                                    onClicked: {
                                        modelData.connectWithPsk(passInput.text)
                                        expandedRoot.selectedNetwork = null
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: netArea
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        onClicked: {
                            if (modelData.connected) {
                                modelData.disconnect()
                            } else {
                                if (expandedRoot.selectedNetwork === modelData) {
                                    expandedRoot.selectedNetwork = null
                                } else {
                                    expandedRoot.selectedNetwork = modelData
                                    if (modelData.security === 0 || modelData.known) {
                                        modelData.connect()
                                    }
                                }
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
