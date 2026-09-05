import QtQuick

// BatteryIcon.qml — Shared battery level icon generator.
// Centralizes the level → icon name mapping used across the shell.

Item {
    id: root

    property int batteryPct: -1
    property string batteryStatus: ""
    property string iconBase: "file:///usr/share/icons/breeze-dark/status/24/"

    function iconName() {
        if (root.batteryPct < 0) return "battery-missing-symbolic";

        let level = Math.max(0, Math.min(100, Math.round(root.batteryPct / 10) * 10));
        let sLevel = (level < 100 ? (level < 10 ? "00" : "0") : "") + level;

        let name = "battery-" + sLevel;
        if (root.batteryStatus === "Charging") name += "-charging";
        name += "-symbolic";

        return name;
    }

    property string iconPath: iconBase + iconName()

    Image {
        id: img
        anchors.fill: parent
        source: root.iconPath
        fillMode: Image.PreserveAspectFit
    }
}
