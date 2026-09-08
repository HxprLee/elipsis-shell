pragma Singleton
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

// Bluetooth singleton — adapter state via Quickshell.Bluetooth + bluetoothctl
// polling. Powers scanning and toggle.
Item {
    id: bluetooth

    property bool bluetoothEnabledManual: false
    property bool bluetoothEnabled: {
        if (bluetoothEnabledManual) return true;
        if (Bluetooth.adapter) return !!Bluetooth.adapter.powered;
        if (Bluetooth.adapters && Bluetooth.adapters.values && Bluetooth.adapters.values.length > 0) {
            return !!Bluetooth.adapters.values[0].powered;
        }
        return false;
    }

    Timer {
        interval: 2500; running: true; repeat: true
        triggeredOnStart: true
        onTriggered: btStatusProc.running = true
    }

    Process {
        id: btStatusProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes'"]
        running: false
        onExited: (code) => {
            bluetooth.bluetoothEnabledManual = (code === 0);
        }
    }

    property bool bluetoothConnected: connectedBluetoothDevices.length > 0

    property string bluetoothDeviceName: {
        if (connectedBluetoothDevices.length > 0) {
            let d = connectedBluetoothDevices[0];
            return d.name || d.alias || "Connected";
        }
        return "";
    }

    property var connectedBluetoothDevices: {
        if (!Bluetooth.devices) return [];
        return Bluetooth.devices.values.filter(d => d.connected);
    }

    property bool bluetoothScanningManual: btScanProc.running

    function startBluetoothDiscovery() {
        if (Bluetooth.adapter) {
            Bluetooth.adapter.discovering = true;
        } else if (Bluetooth.adapters && Bluetooth.adapters.values && Bluetooth.adapters.values.length > 0) {
            Bluetooth.adapters.values[0].discovering = true;
        }

        if (!btScanProc.running) {
            btScanProc.running = true;
        }
    }

    Process {
        id: btScanProc
        command: ["sh", "-c", "bluetoothctl --timeout 15 scan on"]
        running: false
    }

    Process { id: btToggleProc; running: false }

    function toggleBluetooth() {
        if (btToggleProc.running) return;
        let cmd = "bluetoothctl power " + (bluetooth.bluetoothEnabled ? "off" : "on");
        console.log("Bluetooth Toggle Command:", cmd);
        btToggleProc.command = ["sh", "-c", cmd];
        btToggleProc.running = true;
    }
}
