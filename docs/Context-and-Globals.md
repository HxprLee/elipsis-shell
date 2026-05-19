# Context & Available Globals

Toggle files are loaded via `Loader` inside `QuickSettings.qml`. The following global objects are available through QML's scope chain.

## `shellRoot` — Global Shell State (defined in `shell.qml`)

### Networking (Wi-Fi & Ethernet)

| Property / Method                  | Type       | Description                                    |
|------------------------------------|------------|------------------------------------------------|
| `shellRoot.wifiDevice`             | `var`      | The Quickshell `WifiDevice` object (or `null`) |
| `shellRoot.wifiEnabled`            | `bool`     | Whether the Wi-Fi radio is on                  |
| `shellRoot.wifiConnected`          | `bool`     | Whether Wi-Fi is connected to a network        |
| `shellRoot.networkName`            | `string`   | SSID of the connected Wi-Fi network            |
| `shellRoot.ethernetDevice`         | `var`      | The Quickshell Ethernet device (or `null`)      |
| `shellRoot.ethernetConnected`      | `bool`     | Whether an Ethernet connection is active       |
| `shellRoot.activeEthernetName`     | `string`   | Name of the active Ethernet connection         |
| `shellRoot.ethernetIface`          | `string`   | Ethernet interface name (e.g. `"enp0s31f6"`)   |
| `shellRoot.networkEnabled`         | `bool`     | `true` if Wi-Fi or Ethernet is connected       |
| `shellRoot.networkConnected`       | `bool`     | Alias for `networkEnabled`                     |
| `shellRoot.networkType`            | `string`   | `"ethernet"` or `"wifi"`                       |
| `shellRoot.networkSignalLevel`     | `int`      | Wi-Fi signal strength (0–4)                    |
| `shellRoot.isScanningNetwork`      | `bool`     | `true` while a Wi-Fi scan is in progress       |
| `shellRoot.connectWifi(ssid, pw)`  | `function` | Connects to a Wi-Fi network                   |
| `shellRoot.disconnectEthernet()`   | `function` | Disconnects the active Ethernet connection     |
| `shellRoot.connectEthernet()`      | `function` | Connects the Ethernet interface                |
| `shellRoot.refreshNetwork()`       | `function` | Triggers a Wi-Fi network scan                  |
| `shellRoot.toggleWifi()`           | `function` | Toggles the Wi-Fi radio on/off                 |

### Bluetooth

| Property / Method                          | Type       | Description                                    |
|--------------------------------------------|------------|------------------------------------------------|
| `shellRoot.bluetoothEnabled`               | `bool`     | Whether Bluetooth is powered on                |
| `shellRoot.bluetoothConnected`             | `bool`     | Whether any BT device is connected             |
| `shellRoot.bluetoothDeviceName`            | `string`   | Name of the connected BT device                |
| `shellRoot.bluetoothScanningManual`        | `bool`     | `true` while a BT scan is running              |
| `shellRoot.startBluetoothDiscovery()`      | `function` | Starts Bluetooth device discovery              |
| `shellRoot.toggleBluetooth()`              | `function` | Toggles Bluetooth power on/off                 |

### Battery

| Property                   | Type     | Description                                   |
|----------------------------|----------|-----------------------------------------------|
| `shellRoot.batteryPct`     | `int`    | Battery percentage (`-1` if no battery)        |
| `shellRoot.batteryStatus`  | `string` | `"Charging"`, `"Discharging"`, `"Full"`, etc.  |

### Power Profiles

| Property / Method                    | Type       | Description                                          |
|--------------------------------------|------------|------------------------------------------------------|
| `shellRoot.powerProfile`             | `string`   | Current profile: `"balanced"`, `"performance"`, `"power-saver"` |
| `shellRoot.setPowerProfile(profile)` | `function` | Sets the active power profile                        |

### Caffeine

| Property / Method                  | Type       | Description                              |
|------------------------------------|------------|------------------------------------------|
| `shellRoot.caffeineActive`         | `bool`     | Whether caffeine (idle inhibit) is active |
| `shellRoot.setCaffeine(active)`    | `function` | Enables or disables caffeine              |

### UI State & Utilities

| Property / Method            | Type       | Description                                      |
|------------------------------|------------|--------------------------------------------------|
| `shellRoot.panelOpen`        | `bool`     | Whether the control center panel is open          |
| `shellRoot.powerMenuOpen`    | `bool`     | Whether the power menu is open                    |
| `shellRoot.icon(name)`       | `function` | Resolves a Freedesktop icon name to a file path   |

---

## `qs` — QuickSettings Panel (defined in `QuickSettings.qml`)

The `qs` id refers to the `PanelWindow` that hosts the control center. Commonly used properties:

| Property / Method           | Type       | Description                                          |
|-----------------------------|------------|------------------------------------------------------|
| `qs.isOpen`                 | `bool`     | Whether the panel is currently open                  |
| `qs.audioNode`              | `var`      | The Pipewire default audio sink's `audio` object     |
| `qs.wifiEnabled`            | `bool`     | Mirror of `shellRoot.wifiEnabled`                    |
| `qs.bluetoothEnabled`       | `bool`     | Mirror of `shellRoot.bluetoothEnabled`               |
| `qs.brightnessValue`        | `int`      | Current backlight brightness (0–100)                 |
| `qs.setBrightness(pct)`     | `function` | Sets backlight brightness via logind                 |
| `qs.toggleWifi()`           | `function` | Delegates to `shellRoot.toggleWifi()`                |
| `qs.toggleBluetooth()`      | `function` | Delegates to `shellRoot.toggleBluetooth()`           |

---

## `controlPanel` — Grid Container

| Property       | Type   | Description                                              |
|----------------|--------|----------------------------------------------------------|
| `editMode`     | `bool` | `true` when the user is in Edit Mode (drag/resize/remove) |

Use this to block interaction during edit mode:

```qml
MouseArea {
    anchors.fill: parent
    enabled: controlPanel.editMode
}
```

---

## `expandedOverlay` — Expanded View State

Available inside your `expandedComponent`:

| Property     | Type   | Description                                            |
|--------------|--------|--------------------------------------------------------|
| `isExpanded` | `bool` | `true` when the expanded card is open and fully morphed |

Use this to conditionally enable features only when visible:

```qml
Binding {
    target: someObject
    property: "scannerEnabled"
    value: root.isActive && expandedOverlay.isExpanded
    when: someObject !== null
}
```
