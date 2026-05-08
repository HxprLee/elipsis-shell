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
            implicitHeight: contentLayout.implicitHeight

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
                id: contentLayout
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
                    contentHeight: innerCol.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar { }

                    ColumnLayout {
                        id: innerCol
                        width: scrollView.width
                        spacing: 12

                        // Load the heavy network list asynchronously to avoid freezing the shell
                        Loader {
                            id: networksLoader
                            Layout.fillWidth: true
                            asynchronous: true
                            active: false // Started by timer
                            sourceComponent: networksComponent
                        }

                        // Loading indicator
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: networksLoader.status !== Loader.Ready && root.isActive
                            spacing: 10
                            Layout.topMargin: 40
                            
                            BusyIndicator {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 32; implicitHeight: 32
                            }
                            Text {
                                text: "Searching for networks..."
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        Timer {
                            id: delayLoadTimer
                            interval: 350 // Wait for morph animation to finish
                            running: true
                            onTriggered: {
                                networksLoader.active = true
                                if (root.isActive) {
                                    shellRoot.startWifiScan()
                                }
                            }
                        }
                    }
                }

                Component {
                    id: networksComponent
                    ColumnLayout {
                        spacing: 12
                        
                        // Internal filtered models to avoid redundant expensive filtering
                        property var allNetworks: shellRoot.wifiDevice ? shellRoot.wifiDevice.networks.values : []
                        property var knownNetworks: allNetworks.filter(n => n.known)
                        property var unknownNetworks: allNetworks.filter(n => !n.known)

                        // --- Saved Networks Section ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            visible: knownNetworks.length > 0

                            Text {
                                text: "Saved Networks"
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 12
                                font.bold: true
                                Layout.leftMargin: 4
                            }

                            Repeater {
                                model: knownNetworks
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
                                        onClicked: shellRoot.startWifiScan()
                                    }
                                }
                            }

                            Repeater {
                                id: availableRepeater
                                model: unknownNetworks
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

                            RowLayout {
                                id: mainRow
                                Layout.fillWidth: true
                                Layout.preferredHeight: modelData.connected ? 40 : 30
                                Layout.leftMargin: 12
                                Layout.rightMargin: 12
                                spacing: 10

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

                                ColumnLayout {
                                    Layout.fillWidth: true
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
                                        Layout.fillWidth: true
                                    }
                                }

                                Image {
                                    visible: modelData.connected
                                    sourceSize: Qt.size(16, 16)
                                    source: shellRoot.icon("object-select-symbolic")
                                }

                                Image {
                                    visible: !modelData.connected && modelData.security !== 0
                                    sourceSize: Qt.size(14, 14)
                                    source: shellRoot.icon("system-lock-screen-symbolic")
                                    opacity: 0.5
                                }
                            }

                            Loader {
                                id: passLoader
                                Layout.fillWidth: true
                                active: delegateRoot.isExpanded
                                sourceComponent: passwordInputComponent
                                visible: delegateRoot.isExpanded
                            }
                        }

                        MouseArea {
                            id: netArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (modelData.connected) {
                                    modelData.disconnect();
                                } else if (modelData.known || modelData.security === 0) {
                                    shellRoot.connectWifi(modelData.name, "");
                                } else {
                                    if (expandedRoot.selectedNetwork === modelData)
                                        expandedRoot.selectedNetwork = null;
                                    else
                                        expandedRoot.selectedNetwork = modelData;
                                }
                            }
                        }
                    }
                }

                Component {
                    id: passwordInputComponent
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        Layout.bottomMargin: 12
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 40
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.1)
                            border.color: passInput.activeFocus ? root.activeColor : "transparent"
                            border.width: 1

                            TextField {
                                id: passInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                placeholderText: "Password"
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.3)
                                echoMode: TextField.Password
                                color: "white"
                                font.pixelSize: 14
                                background: null
                                focus: true
                            }
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
                                shellRoot.connectWifi(modelData.name, passInput.text);
                                expandedRoot.selectedNetwork = null;
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
