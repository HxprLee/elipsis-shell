import Quickshell
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "services"

Row {
    id: cluster
    property color color: "white"
    property int batteryPct: -1
    property string batteryStatus: ""

    spacing: 12

    // 2. Bluetooth
    Item {
        width: (Bluetooth.bluetoothEnabled && Bluetooth.bluetoothConnected) ? 20 : 0
        height: 20
        visible: width > 0
        anchors.verticalCenter: parent.verticalCenter
        Image {
            id: btIcon
            anchors.fill: parent
            source: Icons.icon(Bluetooth.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
            sourceSize: Qt.size(24, 24)
            visible: false
        }
        ColorOverlay {
            anchors.fill: btIcon
            source: btIcon
            color: cluster.color
            Behavior on color { ColorAnimation { duration: 400 } }
        }
    }

    // 3. Network
    Item {
        width: Network.networkConnected ? 20 : 0
        height: 20
        visible: width > 0
        anchors.verticalCenter: parent.verticalCenter
        Image {
            id: networkIcon
            anchors.fill: parent
            source: {
                if (Network.networkType === "ethernet") {
                    return Icons.icon("network-wired-symbolic");
                }

                let levels = ["none", "weak", "ok", "good", "excellent"];
                let level = levels[Network.networkSignalLevel] || "none";
                return Icons.icon("network-wireless-signal-" + level + "-symbolic");
            }
            sourceSize: Qt.size(24, 24)
            visible: false
        }
        ColorOverlay {
            anchors.fill: networkIcon
            source: networkIcon
            color: cluster.color
            Behavior on color { ColorAnimation { duration: 400 } }
        }

        ToolTip.visible: networkMouse.containsMouse && (Network.ethernetConnected || Network.networkName !== "")
        ToolTip.text: Network.ethernetConnected ? "Ethernet" : Network.networkName
        MouseArea {
            id: networkMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    // 3.5 Power Profile
    Item {
        width: PowerProfiles.powerProfile !== "" ? 20 : 0
        height: 20
        visible: width > 0
        anchors.verticalCenter: parent.verticalCenter
        Image {
            id: profileIcon
            anchors.fill: parent
            source: Icons.icon("power-profile-" + PowerProfiles.powerProfile)
            sourceSize: Qt.size(24, 24)
            visible: false
        }
        ColorOverlay {
            anchors.fill: profileIcon
            source: profileIcon
            color: cluster.color
            Behavior on color { ColorAnimation { duration: 400 } }
        }
    }

    // 4. Battery
    Row {
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        Item {
            width: 20; height: 20
            anchors.verticalCenter: parent.verticalCenter
            Image {
                id: battIcon
                anchors.fill: parent
                source: {
                    let isCharging = cluster.batteryStatus === "Charging"
                    let pct = cluster.batteryPct
                    if (pct < 0) return Icons.icon("battery-missing-symbolic")

                    let level = Math.max(0, Math.min(100, Math.round(pct / 10) * 10))
                    let sLevel = (level < 100 ? (level < 10 ? "00" : "0") : "") + level

                    let name = "battery-" + sLevel
                    if (isCharging) name += "-charging"
                    name += "-symbolic"

                    return Icons.icon(name)
                }
                sourceSize: Qt.size(24, 24)
                visible: false
            }
            ColorOverlay {
                anchors.fill: battIcon
                source: battIcon
                color: cluster.color
                Behavior on color { ColorAnimation { duration: 400 } }
            }
        }
        Text {
            text: cluster.batteryPct >= 0 ? cluster.batteryPct + "%" : "—"
            color: cluster.color
            font.pixelSize: 15
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 400 } }
        }
    }
}
