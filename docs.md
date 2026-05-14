# Elipsis Shell — Documentation

---

## IPC Reference

All IPC calls use the Quickshell IPC mechanism. Invoke them from the command line with:

```bash
qs ipc call  <target> <function> [args...]
```

### `lock` — Session Lock

Defined in [`shell.qml`](shell.qml)

| Function   | Arguments | Description                      |
| ---------- | --------- | -------------------------------- |
| `toggle`   | —         | Toggle the lock screen           |
| `lock`     | —         | Lock the session                 |
| `unlock`   | —         | Unlock the session               |

```bash
qs ipc call lock lock
qs ipc call lock unlock
qs ipc call lock toggle
```

### `task_manager` — Task Switcher

Defined in [`components/TaskManager.qml`](components/TaskManager.qml)

| Function | Arguments | Description                    |
| -------- | --------- | ------------------------------ |
| `toggle` | —         | Toggle the task switcher       |
| `open`   | —         | Open the task switcher         |
| `close`  | —         | Close the task switcher        |

```bash
qs ipc call task_manager toggle
qs ipc call task_manager open
qs ipc call task_manager close
```

### `appearance` — Visual Settings

Defined in [`shell.qml`](shell.qml)

| Function             | Arguments          | Description                                          |
| -------------------- | ------------------ | ---------------------------------------------------- |
| `setPrecomputedBlur` | `enabled` (string) | Enable/disable static wallpaper blur. Accepts `"true"`, `"1"`, `"false"`, `"0"`. |

```bash
qs ipc call appearance setPrecomputedBlur true
qs ipc call appearance setPrecomputedBlur false
```

### `power` — Power Menu

Defined in [`shell.qml`](shell.qml)

| Function | Arguments | Description                    |
| -------- | --------- | ------------------------------ |
| `show`   | —         | Open the power menu            |
| `hide`   | —         | Close the power menu           |
| `toggle` | —         | Toggle the power menu          |

```bash
qs ipc call power show
qs ipc call power hide
qs ipc call power toggle
```

### `quicksettings` — Quick Settings Panel

Defined in [`shell.qml`](shell.qml)

| Function | Arguments | Description                    |
| -------- | --------- | ------------------------------ |
| `show`   | —         | Open the quick settings panel  |
| `hide`   | —         | Close the quick settings panel |
| `toggle` | —         | Toggle the quick settings panel|

```bash
qs ipc call quicksettings show
qs ipc call quicksettings hide
qs ipc call quicksettings toggle
```

---

## Creating Custom Control Center Toggles

This section covers how to create custom toggles for the Control Center, from the simplest on/off toggle to complex widgets with full expanded UIs.

### Overview

The Control Center uses a **data-driven architecture**. Toggle files in `components/toggles/` provide **data and behavior only** — the shell renders the visual chrome (background, icon, label, click handling) automatically.

#### How It Works

```
┌───────────────────────────────────────────────────┐
│  Your Toggle File (e.g. MyToggle.qml)             │
│  ┌────────────────────────────────────────────┐   │
│  │ isSimpleToggle: true                       │   │
│  │ toggleName:     "My Toggle"                │   │
│  │ iconSource:     shellRoot.icon("...")      │   │
│  │ isActive:       <your logic>               │   │
│  │ activeColor:    Qt.rgba(...)               │   │
│  │ signal toggled()                           │   │
│  └────────────────────────────────────────────┘   │
│              ↓ read by shell                      │
│  ┌────────────────────────────────────────────┐   │
│  │ Shell Chrome (auto-rendered)               │   │
│  │ • 1×1: circle with icon                    │   │
│  │ • 2×1: pill with icon + label              │   │
│  │ • Active state: fills with activeColor     │   │
│  │ • Tap: emits toggled()                     │   │
│  │ • Long-press: opens expanded view (opt-in) │   │
│  └────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────┘
```

---

### Simple Toggle (No Expanded UI)

A simple toggle is a data-only QML `Item` with no visual content. The shell handles all rendering.

#### Required Interface

| Property / Signal | Type     | Description                                          |
|-------------------|----------|------------------------------------------------------|
| `isControlWidget` | `bool`   | Must be `true` — registers the file as a control widget |
| `isSimpleToggle`  | `bool`   | Must be `true` — tells the shell to render chrome    |
| `toggleName`       | `string` | Static name/description of the toggle. |
| `titleText`    | `string` | Title shown in the Control Center, can be updated dynamically. If undefined, `toggleName` is used. |
| `subtitleText`    | `string` | Optional secondary label (shown in 2×1 pill layout). Use QML bindings for dynamic updates. |
| `iconSource`      | `string` | Icon path (use `shellRoot.icon("name")` for lookup)  |
| `isActive`        | `bool`   | Whether the toggle is "on" — drives color & styling  |
| `activeColor`     | `color`  | Background fill color when `isActive` is `true`      |
| `toggled()`       | `signal` | Emitted when the user taps the toggle                |

#### Minimal Example — `DndToggle.qml`

```qml
import QtQuick

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "DND"
    property string iconSource: shellRoot.icon("notifications-disabled-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: console.log("DND toggled")
}
```

That's it — **15 lines**. No visual elements, no layouts. The shell does the rest.

#### Dynamic State Example — `PowerProfileToggle.qml`

Properties can use bindings and expressions to react to system state:

```qml
import QtQuick

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Power Profile"

    // Dynamic subtitle based on current profile
    property string subtitleText: {
        if (shellRoot.powerProfile === "power-saver") return "Power Saver";
        if (shellRoot.powerProfile === "performance") return "Performance";
        return "Balanced";
    }

    property string iconSource: shellRoot.icon("power-profile-" + shellRoot.powerProfile)
    property bool isActive: true
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)

    signal toggled()
    onToggled: {
        // Cycle through profiles
        if (shellRoot.powerProfile === "power-saver") {
            shellRoot.setPowerProfile("balanced");
        } else if (shellRoot.powerProfile === "balanced") {
            shellRoot.setPowerProfile("performance");
        } else {
            shellRoot.setPowerProfile("power-saver");
        }
    }
}
```

#### Dynamic Subtitles

The `subtitleText` property supports full QML expression bindings. It will automatically re-evaluate whenever any property it depends on changes (e.g., `shellRoot` properties).

**Example — Network Subtitle:**
```qml
property string subtitleText: {
    if (shellRoot.ethernetConnected) return "Connected";
    if (shellRoot.networkName !== "") return "Connected";
    if (qs.wifiEnabled) return "Not Connected";
    return "Off";
}
```

---

### Toggle with Expanded UI

For toggles that need a richer interface (network lists, detailed settings, etc.), you can add an **expanded view** that opens on long-press.

#### Additional Properties

Add these alongside the simple toggle interface:

| Property             | Type        | Description                                           |
|----------------------|-------------|-------------------------------------------------------|
| `hasExpandedView`    | `bool`      | Must be `true` — enables long-press expansion         |
| `expandedComponent`  | `Component` | The QML component to render inside the expanded card  |

#### How the Expansion Works

1. User **long-presses** the toggle in the grid
2. A card appears at the toggle's position
3. The card **morphs** (animates) to a centered overlay (full panel width × 420px)
4. Your `expandedComponent` fades in inside the card (with 24px padding)
5. Tapping **outside** the card morphs it back and dismisses it

#### Template

```qml
import QtQuick
import QtQuick.Layouts
import ".."    // ← Required to access ExpandedHeader from components/

Item {
    id: root
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "My Toggle"
    property string iconSource: shellRoot.icon("my-icon-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)

    property bool hasExpandedView: true
    property Component expandedComponent: Component {
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 16

                // ── Reusable Header ──
                ExpandedHeader {
                    Layout.fillWidth: true
                    toggle: root
                    showSwitch: true
                    onSwitchToggled: root.toggled()
                }

                // ── Your content here ──
                // The remaining space (Layout.fillHeight)
                // is yours for lists, grids, settings, etc.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        text: "Your expanded content"
                        color: "white"
                    }
                }
            }
        }
    }

    signal toggled()
    onToggled: { /* your toggle logic */ }
}
```

---

### `ExpandedHeader` Component Reference

**File:** `components/ExpandedHeader.qml`

A drop-in header that gives your expanded view a consistent look: icon badge, title, subtitle, optional trailing content, optional toggle switch, and a divider line.

#### Properties

| Property          | Type     | Default  | Required | Description                              |
|-------------------|----------|----------|----------|------------------------------------------|
| `toggle`          | `var`    | `null`   | No       | Reference to the toggle item. Auto-reads `titleText`/`toggleName`, `subtitleText`, `iconSource`, `isActive`, `activeColor`. |
| `title`           | `string` | auto     | No       | Main heading text. Auto-read from `toggle.titleText` (or `toggleName`) if `toggle` is set. |
| `subtitle`        | `string` | auto     | No       | Secondary text (auto-hidden when empty). Auto-read from `toggle.subtitleText`. |
| `iconSource`      | `string` | auto     | No       | Icon for the 48px circular badge. Auto-read from `toggle.iconSource`. |
| `isActive`        | `bool`   | auto     | No       | Controls active/inactive colors. Auto-read from `toggle.isActive`. |
| `activeColor`     | `color`  | blue     | No       | Accent color for badge & switch track. Auto-read from `toggle.activeColor`. |
| `showSwitch`      | `bool`   | `false`  | No       | Shows the toggle switch.               |
| `showButton`      | `bool`   | `false`  | No       | Shows a customizable button instead of the switch. Mutually exclusive with `showSwitch`. |
| `buttonText`      | `string` | `""`     | No       | Text displayed on the button. |
| `buttonIconSource`| `string` | `""`     | No       | Icon displayed on the button. |
| `isButtonActive`  | `bool`   | `false`  | No       | Drives the filled active color state of the button. |
| `buttonActiveColor`| `color` | auto     | No       | Active color for the button. Defaults to `header.activeColor`. |
| `trailingContent` | `Item`   | —        | No       | Slot for extra buttons before the switch/button |

#### Signals

| Signal           | Emitted When                    |
|------------------|---------------------------------|
| `switchToggled()`| The switch is tapped            |
| `buttonClicked()`| The button is tapped            |

#### Visual Layout

```
┌─────────────────────────────────────────────────┐
│  ╭──────╮                                       │
│  │ ICON │  Title            [Trailing] [Switch] │
│  │      │  Subtitle                             │
│  ╰──────╯                                       │
│─────────────────────────────────────────────────│
│  (divider line)                                 │
└─────────────────────────────────────────────────┘
```

#### Usage Variations

**With toggle reference (preferred):**
```qml
ExpandedHeader {
    Layout.fillWidth: true
    toggle: root
}
```

**With toggle + switch:**
```qml
ExpandedHeader {
    Layout.fillWidth: true
    toggle: root
    showSwitch: true
    onSwitchToggled: root.toggled()
}
```

**With toggle + button:**
```qml
ExpandedHeader {
    Layout.fillWidth: true
    toggle: root
    showButton: true
    buttonText: "Action"
    buttonIconSource: shellRoot.icon("media-playback-start-symbolic")
    isButtonActive: root.isActive
    onButtonClicked: { /* action logic */ }
}
```

**With toggle + switch + trailing content:**
```qml
ExpandedHeader {
    Layout.fillWidth: true
    toggle: root
    showSwitch: true
    onSwitchToggled: root.toggled()

    trailingContent: Rectangle {
        width: 32; height: 32; radius: 16
        color: Qt.rgba(1, 1, 1, 0.1)
        Image {
            anchors.centerIn: parent
            width: 16; height: 16
            source: shellRoot.icon("view-refresh-symbolic") || ""
        }
        MouseArea {
            anchors.fill: parent
            onClicked: { /* refresh action */ }
        }
    }
}
```

---

### Context & Available Globals

Toggle files are loaded via `Loader` inside `QuickSettings.qml`. The following global objects are available through QML's scope chain.

#### `shellRoot` — Global Shell State (defined in `shell.qml`)

##### Networking (Wi-Fi & Ethernet)

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

##### Bluetooth

| Property / Method                          | Type       | Description                                    |
|--------------------------------------------|------------|------------------------------------------------|
| `shellRoot.bluetoothEnabled`               | `bool`     | Whether Bluetooth is powered on                |
| `shellRoot.bluetoothConnected`             | `bool`     | Whether any BT device is connected             |
| `shellRoot.bluetoothDeviceName`            | `string`   | Name of the connected BT device                |
| `shellRoot.bluetoothScanningManual`        | `bool`     | `true` while a BT scan is running              |
| `shellRoot.startBluetoothDiscovery()`      | `function` | Starts Bluetooth device discovery              |
| `shellRoot.toggleBluetooth()`              | `function` | Toggles Bluetooth power on/off                 |

##### Battery

| Property                   | Type     | Description                                   |
|----------------------------|----------|-----------------------------------------------|
| `shellRoot.batteryPct`     | `int`    | Battery percentage (`-1` if no battery)        |
| `shellRoot.batteryStatus`  | `string` | `"Charging"`, `"Discharging"`, `"Full"`, etc.  |

##### Power Profiles

| Property / Method                    | Type       | Description                                          |
|--------------------------------------|------------|------------------------------------------------------|
| `shellRoot.powerProfile`             | `string`   | Current profile: `"balanced"`, `"performance"`, `"power-saver"` |
| `shellRoot.setPowerProfile(profile)` | `function` | Sets the active power profile                        |

##### Caffeine

| Property / Method                  | Type       | Description                              |
|------------------------------------|------------|------------------------------------------|
| `shellRoot.caffeineActive`         | `bool`     | Whether caffeine (idle inhibit) is active |
| `shellRoot.setCaffeine(active)`    | `function` | Enables or disables caffeine              |

##### UI State & Utilities

| Property / Method            | Type       | Description                                      |
|------------------------------|------------|--------------------------------------------------|
| `shellRoot.panelOpen`        | `bool`     | Whether the control center panel is open          |
| `shellRoot.powerMenuOpen`    | `bool`     | Whether the power menu is open                    |
| `shellRoot.icon(name)`       | `function` | Resolves a Freedesktop icon name to a file path   |

---

#### `qs` — QuickSettings Panel (defined in `QuickSettings.qml`)

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

#### `controlPanel` — Grid Container

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

#### `expandedOverlay` — Expanded View State

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

---

### File Discovery & Registration

#### Discovery via `isControlWidget`

Any `.qml` file placed in `components/toggles/` will be loaded. However, only files that export `isControlWidget: true` will appear. Files without this property (e.g., utility components) will be ignored.

```qml
Item {
    property bool isControlWidget: true  // ← Required to be recognized as toggle
    property string toggleName: "My Toggle"
    // ...
}
```

#### Recommended Naming

While file names don't affect discovery, it's recommended to use these suffixes for readability:

| Suffix           | Convention                                 |
|------------------|--------------------------------------------|
| `*Toggle.qml`   | On/off toggles (WiFi, Bluetooth, DND)      |
| `*Slider.qml`   | Continuous controls (Brightness, Volume)    |
| `*Widget.qml`   | Large custom content (Media player)         |

#### Import Requirements

If your toggle uses `ExpandedHeader` or any other component from `components/`, you **must** add:

```qml
import ".."
```

This is because toggles are loaded via `Loader` from `QuickSettings.qml`, and types in the parent `components/` directory aren't auto-resolved from the `toggles/` subdirectory.

#### Layout Registration

After creating your file, add it to `config/control_center_layout.json`:

```json
{
    "source": "toggles/YourToggle.qml",
    "colSpan": 1,
    "rowSpan": 1
}
```

Or use **Edit Mode** (tap "Edit" in the Control Center header) → tap the **+** button to add your toggle from the picker.

---

### Grid Sizing

| `colSpan × rowSpan` | Visual Shape        | Chrome Renders                   |
|----------------------|---------------------|----------------------------------|
| `1 × 1`             | Circle              | Icon only (centered)             |
| `2 × 1`             | Horizontal pill     | Icon + label side-by-side        |
| `2 × 2`             | Large card          | Icon + label (custom layout OK)  |
| `4 × 2`             | Full-width card     | Custom widget (e.g. media)       |

Users can cycle sizes in Edit Mode by tapping the toggle.

#### Restricting Sizes (`availableSizes`)

By default, the shell allows users to cycle through generic widget sizes in Edit Mode by tapping the corner resize handle. To take control of which sizes your toggle supports, export the `availableSizes` property as an array of objects. The shell will cycle exactly through these sizes when the resize button is tapped:

```qml
property var availableSizes: [
    { colSpan: 2, rowSpan: 2 }, // 2x2 Square
    { colSpan: 4, rowSpan: 2 }  // 4x2 Full width
]
```

#### Responsive Layouts

You can create complex toggles that adapt their layout based on the user's chosen size by reading `modelData.colSpan` and `modelData.rowSpan`.

For example, using a `GridLayout` to switch between a stacked layout and a side-by-side layout depending on width:

```qml
GridLayout {
    anchors.fill: parent
    // If width is 4 columns, use 2 columns internally; otherwise use 1 column.
    columns: (modelData && modelData.colSpan === 4) ? 2 : 1
    
    // ...
}
```

---

### Quick Reference — Copy-Paste Templates

#### Minimal Toggle

```qml
import QtQuick

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "My Toggle"
    property string iconSource: shellRoot.icon("my-icon-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: { /* your logic */ }
}
```

#### Toggle with Expanded View

```qml
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "My Toggle"
    property string iconSource: shellRoot.icon("my-icon-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)

    property bool hasExpandedView: true
    property Component expandedComponent: Component {
        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 16

                ExpandedHeader {
                    Layout.fillWidth: true
                    toggle: root
                    showSwitch: true
                    onSwitchToggled: root.toggled()
                }

                // Your content below the header
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    // ...
                }
            }
        }
    }

    signal toggled()
    onToggled: { /* your logic */ }
}
```
