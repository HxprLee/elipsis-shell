import Quickshell
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Row {
    id: cluster
    property color color: "white"
    property int batteryPct: -1
    property string batteryStatus: ""

    spacing: 12

    // 2. Bluetooth
    Item {
        width: (shellRoot.bluetoothEnabled && shellRoot.bluetoothConnected) ? 20 : 0
        height: 20
        visible: width > 0
        anchors.verticalCenter: parent.verticalCenter
        Image {
            id: btIcon
            anchors.fill: parent
            source: shellRoot.icon(shellRoot.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
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
        width: shellRoot.networkEnabled ? 20 : 0
        height: 20
        visible: width > 0
        anchors.verticalCenter: parent.verticalCenter
        Image {
            id: networkIcon
            anchors.fill: parent
            source: {
                if (shellRoot.networkType === "ethernet") {
                    return shellRoot.icon("network-wired-symbolic");
                }

                let levels = ["none", "weak", "ok", "good", "excellent"];
                let level = levels[shellRoot.networkSignalLevel] || "none";
                return shellRoot.icon("network-wireless-signal-" + level + "-symbolic");
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

        ToolTip.visible: networkMouse.containsMouse && (shellRoot.ethernetConnected || shellRoot.networkName !== "")
        ToolTip.text: shellRoot.ethernetConnected ? "Ethernet" : shellRoot.networkName
        MouseArea {
            id: networkMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }

    // 3.5 Power Profile
    Item {
        width: shellRoot.powerProfile !== "" ? 20 : 0
        height: 20
        visible: width > 0
        anchors.verticalCenter: parent.verticalCenter
        Image {
            id: profileIcon
            anchors.fill: parent
            source: shellRoot.icon("power-profile-" + shellRoot.powerProfile)
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
                    if (pct < 0) return shellRoot.icon("battery-missing-symbolic")

                    let level = Math.max(0, Math.min(100, Math.round(pct / 10) * 10))
                    let sLevel = (level < 100 ? (level < 10 ? "00" : "0") : "") + level

                    let name = "battery-" + sLevel
                    if (isCharging) name += "-charging"
                    name += "-symbolic"

                    return shellRoot.icon(name)
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
