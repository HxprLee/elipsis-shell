pragma Singleton
import Quickshell.Services.UPower
import QtQuick

// Battery singleton — exposes UPower.displayDevice.percentage and state.
// Consumers read Battery.batteryPct / Battery.batteryStatus.

Item {
    id: battery

    property int batteryPct: -1
    property string batteryStatus: ""

    Binding on batteryPct {
        value: UPower.displayDevice && UPower.displayDevice.percentage >= 0.01
            ? Math.round(UPower.displayDevice.percentage * 100)
            : -1
    }
    Binding on batteryStatus {
        value: UPower.displayDevice
            ? UPowerDeviceState.toString(UPower.displayDevice.state)
            : ""
    }

    Component.onCompleted: {
        console.log("UPower displayDevice:", UPower.displayDevice);
        console.log("UPower displayDevice percentage:", UPower.displayDevice?.percentage);
        console.log("UPower displayDevice state:", UPower.displayDevice?.state);
    }
}
