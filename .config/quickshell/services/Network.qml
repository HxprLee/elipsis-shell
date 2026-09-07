pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// Network singleton — wifi/ethernet state via Quickshell.Networking + nmcli.
// Owns wifi/ethernet properties, polling timer, nmcli-backed scan/toggle.
QtObject {
    id: network

    // ── Wifi ──
    property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi) return devices[i];
        }
        return null;
    }

    property bool wifiEnabled: Networking.wifiEnabled ?? false
    property bool wifiConnected: !!(wifiDevice && wifiDevice.connected)

    // ── Ethernet ──
    property var ethernetDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Ethernet) return devices[i];
        }
        return null;
    }
    property string networkName: ""
    property string activeEthernetName: ""
    property string ethernetIface: ""

    // ── Polling ──
    Process {
        id: netPollProc
        command: ["sh", "-c", "nmcli -t -f TYPE,NAME con show --active | grep -E '802-11-wireless|wireless|802-3-ethernet|ethernet|wired'; nmcli -t -f DEVICE,TYPE device | grep -iE 'ethernet|wired'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.trim().split("\n");
                let wifi = "";
                let eth = "";
                let iface = "";

                for (let line of lines) {
                    let parts = line.split(":");
                    if (parts.length < 2) continue;
                    let type = parts[0].toLowerCase();
                    let name = parts[1];

                    if (type.includes("wireless") || type.includes("wifi")) {
                        if (wifi === "") wifi = name;
                    } else if (type.includes("ethernet") || type.includes("wired")) {
                        // nmcli device output format is DEVICE:TYPE
                        // nmcli con show output format is TYPE:NAME
                        if (line.includes(":") && !name.includes("ethernet") && !name.includes("wired")) {
                            iface = parts[0];
                        } else {
                            eth = name;
                        }
                    }
                }

                network.networkName = wifi;
                network.activeEthernetName = eth;
                if (iface !== "") network.ethernetIface = iface;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: netPollProc.running = true
    }

    Process {
        id: ethToggleProc
        running: false
    }

    function disconnectEthernet() {
        if (activeEthernetName) {
            ethToggleProc.command = ["nmcli", "connection", "down", activeEthernetName];
            ethToggleProc.running = true;
        }
    }

    function connectEthernet() {
        if (ethernetIface !== "") {
            ethToggleProc.command = ["nmcli", "device", "connect", ethernetIface];
            ethToggleProc.running = true;
        }
    }

    property bool ethernetConnected: activeEthernetName !== ""
    property bool networkEnabled: wifiConnected || ethernetConnected
    property bool networkConnected: wifiConnected || ethernetConnected
    property string networkType: ethernetConnected ? "ethernet" : "wifi"

    // Signal level from 0 to 4
    property int networkSignalLevel: {
        if (!wifiDevice || !wifiDevice.connected || !wifiDevice.networks) return 0;
        const networks = wifiDevice.networks.values;
        for (let i = 0; i < networks.length; i++) {
            let net = networks[i];
            if (net.connected) {
                let s = net.signalStrength;
                if (s >= 0.8) return 4;
                if (s >= 0.6) return 3;
                if (s >= 0.4) return 2;
                if (s >= 0.2) return 1;
                return 0;
            }
        }
        return 0;
    }

    // ── Scan ──
    property bool isScanningNetwork: networkScanProc.running

    function refreshNetwork() {
        if (networkScanProc.running) return;
        if (Networking.wifi) {
            Networking.wifi.scan();
        }
        networkScanProc.running = true;
    }

    Process {
        id: networkScanProc
        command: ["nmcli", "device", "wifi", "rescan"]
        running: false
    }

    Process { id: wifiToggleProc; running: false }

    function toggleWifi() {
        if (wifiToggleProc.running) return;
        wifiToggleProc.command = ["sh", "-c", "nmcli radio wifi " + (network.wifiEnabled ? "off" : "on")];
        wifiToggleProc.running = true;
    }
}
