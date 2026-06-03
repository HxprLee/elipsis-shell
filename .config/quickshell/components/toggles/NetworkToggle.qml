import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Networking
import ".."
import "../reusables"

Item {
    id: root
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property bool isWired: shellRoot.ethernetConnected

    // Dynamic Title support
    property string titleText: isWired ? "Ethernet" : (shellRoot.networkName !== "" ? shellRoot.networkName : "Networks")
    property string toggleName: "Network"

    property string subtitleText: isWired ? "Connected" : (shellRoot.networkName !== "" ? "Connected" : (qs.wifiEnabled ? "Not Connected" : "Off"))
    property string iconSource: shellRoot.icon(isWired ? "network-wired-symbolic" : (qs.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic"))
    property bool isActive: qs.wifiEnabled || isWired
    property color activeColor: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)

    // Expanded view support
    property bool hasExpandedView: true
    property int expandedHeight: 480
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
                    toggle: root
                    showSwitch: true
                    onSwitchToggled: root.toggled()
                }

                // Scrollable Content
                Flickable {
                    id: scrollView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: innerCol.implicitHeight
                    contentHeight: innerCol.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar {}

                    ColumnLayout {
                        id: innerCol
                        width: scrollView.width
                        spacing: 12

                        // Load the heavy network list asynchronously to avoid freezing the shell
                        Loader {
                            id: networksLoader
                            Layout.fillWidth: true
                            asynchronous: true
                            active: true
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
                                implicitWidth: 32
                                implicitHeight: 32
                            }
                            Text {
                                text: "Searching for networks..."
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                Component {
                    id: networksComponent
                    ColumnLayout {
                        width: scrollView.width // Use scrollView width directly to prevent collapse
                        spacing: 12

                        Component.onCompleted: {
                            if (root.isActive) {
                                shellRoot.refreshNetwork();
                            }
                        }

                        // Internal filtered models to avoid redundant expensive filtering
                        property var allNetworks: {
                            let nets = shellRoot.wifiDevice ? shellRoot.wifiDevice.networks.values : [];
                            return nets.slice().sort((a, b) => {
                                if (a.connected)
                                    return -1;
                                if (b.connected)
                                    return 1;
                                return (b.signalStrength || 0) - (a.signalStrength || 0);
                            });
                        }
                        property var knownNetworks: allNetworks.filter(n => n.known)
                        property var unknownNetworks: allNetworks.filter(n => !n.known)

                        // --- Wired Section ---
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            visible: shellRoot.ethernetConnected

                            Text {
                                text: "Ethernet"
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 12
                                font.bold: true
                                Layout.leftMargin: 4
                            }

                            ToggleListItem {
                                title: shellRoot.activeEthernetName !== "" ? shellRoot.activeEthernetName : (shellRoot.ethernetIface !== "" ? shellRoot.ethernetIface : "Wired Connection")
                                subtitle: shellRoot.ethernetConnected ? "Connected" : "Disconnected"
                                subtitleColor: shellRoot.ethernetConnected ? root.activeColor : Qt.rgba(1, 1, 1, 0.6)
                                iconSource: shellRoot.icon(shellRoot.ethernetConnected ? "network-wired-symbolic" : "network-wired-offline-symbolic")
                                iconOpacity: shellRoot.ethernetConnected ? 1.0 : 0.6
                                showCheckmark: shellRoot.ethernetConnected
                                onClicked: {
                                    if (shellRoot.ethernetConnected) {
                                        shellRoot.disconnectEthernet();
                                    } else {
                                        shellRoot.connectEthernet();
                                    }
                                }
                            }
                        }

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

                                    property bool isScanning: shellRoot.isScanningNetwork

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
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: refreshMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: shellRoot.refreshNetwork()
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
                    ToggleListItem {
                        title: modelData.name || "Hidden Network"
                        subtitle: modelData.connected ? "Connected" : ""
                        subtitleColor: root.activeColor
                        iconSource: {
                            if (modelData.signalStrength >= 0.8)
                                return shellRoot.icon("network-wireless-signal-excellent-symbolic");
                            if (modelData.signalStrength >= 0.6)
                                return shellRoot.icon("network-wireless-signal-good-symbolic");
                            if (modelData.signalStrength >= 0.4)
                                return shellRoot.icon("network-wireless-signal-ok-symbolic");
                            if (modelData.signalStrength >= 0.2)
                                return shellRoot.icon("network-wireless-signal-weak-symbolic");
                            return shellRoot.icon("network-wireless-signal-none-symbolic");
                        }
                        iconOpacity: modelData.connected ? 1.0 : 0.6
                        showCheckmark: modelData.connected
                        showLock: !modelData.connected && modelData.security !== 0
                        isExpanded: expandedRoot.selectedNetwork === modelData && !modelData.connected && modelData.security !== 0 && !modelData.known
                        expandedComponent: passwordInputComponent

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

                Component {
                    id: passwordInputComponent
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        Layout.rightMargin: 12
                        Layout.bottomMargin: 12
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
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
                                onAccepted: {
                                    shellRoot.connectWifi(modelData.name, passInput.text);
                                    expandedRoot.selectedNetwork = null;
                                }
                            }
                        }

                        Rectangle {
                            width: 36
                            height: 36
                            radius: 10
                            color: connectArea.pressed ? Qt.darker(root.activeColor, 1.2) : root.activeColor

                            Image {
                                anchors.centerIn: parent
                                sourceSize: Qt.size(16, 16)
                                source: shellRoot.icon("go-next-symbolic")
                            }

                            MouseArea {
                                id: connectArea
                                anchors.fill: parent
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
    }

    signal toggled
    onToggled: qs.toggleWifi()
}
