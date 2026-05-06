# Creating Custom Control Center Toggles

This guide covers how to create custom toggles for the Control Center, from the simplest on/off toggle to complex widgets with full expanded UIs.

---

## Overview

The Control Center uses a **data-driven architecture**. Toggle files in `components/toggles/` provide **data and behavior only** — the shell renders the visual chrome (background, icon, label, click handling) automatically.

### How It Works

```
┌───────────────────────────────────────────────────┐
│  Your Toggle File (e.g. MyToggle.qml)             │
│  ┌────────────────────────────────────────────┐   │
│  │ isSimpleToggle: true                       │   │
│  │ titleText:      "My Toggle"                │   │
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

## Part 1: Simple Toggle (No Expanded UI)

A simple toggle is a data-only QML `Item` with no visual content. The shell handles all rendering.

### Required Interface

| Property / Signal | Type     | Description                                          |
|-------------------|----------|------------------------------------------------------|
| `isSimpleToggle`  | `bool`   | Must be `true` — tells the shell to render chrome    |
| `titleText`       | `string` | Label text (shown in 2×1 pill layout)                |
| `iconSource`      | `string` | Icon path (use `shellRoot.icon("name")` for lookup)  |
| `isActive`        | `bool`   | Whether the toggle is "on" — drives color & styling  |
| `activeColor`     | `color`  | Background fill color when `isActive` is `true`      |
| `toggled()`       | `signal` | Emitted when the user taps the toggle                |

### Minimal Example — `DndToggle.qml`

```qml
import QtQuick

Item {
    property bool isSimpleToggle: true
    property string titleText: "DND"
    property string iconSource: shellRoot.icon("notifications-disabled-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: console.log("DND toggled")
}
```

That's it — **14 lines**. No visual elements, no layouts. The shell does the rest.

### Dynamic State Example — `PowerProfileToggle.qml`

Properties can use bindings and expressions to react to system state:

```qml
import QtQuick

Item {
    property bool isSimpleToggle: true

    // Dynamic title based on current profile
    property string titleText: {
        if (shellRoot.powerProfile === "power-saver") return "Power Saver";
        if (shellRoot.powerProfile === "performance") return "Performance";
        return "Balanced";
    }

    property string iconSource: shellRoot.icon("power-profile-" + shellRoot.powerProfile)
    property bool isActive: true

    // Dynamic color per state
    property color activeColor: {
        if (shellRoot.powerProfile === "power-saver") return Qt.rgba(0.2, 0.8, 0.2, 1.0);
        if (shellRoot.powerProfile === "performance") return Qt.rgba(1.0, 0.3, 0.2, 1.0);
        return Qt.rgba(0.2, 0.5, 1.0, 1.0);
    }

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

---

## Part 2: Toggle with Expanded UI

For toggles that need a richer interface (network lists, detailed settings, etc.), you can add an **expanded view** that opens on long-press.

### Additional Properties

Add these alongside the simple toggle interface:

| Property             | Type        | Description                                           |
|----------------------|-------------|-------------------------------------------------------|
| `hasExpandedView`    | `bool`      | Must be `true` — enables long-press expansion         |
| `expandedComponent`  | `Component` | The QML component to render inside the expanded card  |

### How the Expansion Works

1. User **long-presses** the toggle in the grid
2. A card appears at the toggle's position
3. The card **morphs** (animates) to a centered overlay (full panel width × 420px)
4. Your `expandedComponent` fades in inside the card (with 24px padding)
5. Tapping **outside** the card morphs it back and dismisses it

### Template

```qml
import QtQuick
import QtQuick.Layouts
import "../reusables"    // ← Required to access ExpandedHeader from components/reusables/

Item {
    id: root
    property bool isSimpleToggle: true
    property string titleText: "My Toggle"
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
                    title: "My Toggle"
                    subtitle: root.isActive ? "On" : "Off"
                    iconSource: root.iconSource
                    isActive: root.isActive
                    activeColor: root.activeColor
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

## Part 3: `ExpandedHeader` Component Reference

**File:** `components/reusables/ExpandedHeader.qml`

A drop-in header that gives your expanded view a consistent look: icon badge, title, subtitle, optional trailing content, optional Material 3 switch, and a divider line.

### Properties

| Property          | Type     | Default  | Required | Description                              |
|-------------------|----------|----------|----------|------------------------------------------|
| `title`           | `string` | `""`     | Yes      | Main heading text                        |
| `subtitle`        | `string` | `""`     | No       | Secondary text (auto-hidden when empty)  |
| `iconSource`      | `string` | `""`     | Yes      | Icon for the 48px circular badge         |
| `isActive`        | `bool`   | `false`  | Yes      | Controls active/inactive colors          |
| `activeColor`     | `color`  | blue     | No       | Accent color for badge & switch track    |
| `showSwitch`      | `bool`   | `false`  | No       | Shows the M3 toggle switch               |
| `trailingContent` | `Item`   | —        | No       | Slot for extra buttons before the switch |

### Signals

| Signal           | Emitted When                    |
|------------------|---------------------------------|
| `switchToggled()`| The Material 3 switch is tapped |

### Visual Layout

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

### Usage Variations

**Header only (no switch):**
```qml
ExpandedHeader {
    Layout.fillWidth: true
    title: "Power Profile"
    subtitle: "Balanced"
    iconSource: root.iconSource
    isActive: root.isActive
    activeColor: root.activeColor
}
```

**With switch:**
```qml
ExpandedHeader {
    Layout.fillWidth: true
    title: "Bluetooth"
    subtitle: root.isActive ? "On" : "Off"
    iconSource: root.iconSource
    isActive: root.isActive
    activeColor: root.activeColor
    showSwitch: true
    onSwitchToggled: root.toggled()
}
```

**With switch + trailing content:**
```qml
ExpandedHeader {
    Layout.fillWidth: true
    title: "Wi-Fi"
    subtitle: root.isActive ? (shellRoot.wifiSsid || "Connected") : "Off"
    iconSource: root.iconSource
    isActive: root.isActive
    activeColor: root.activeColor
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

## Part 4: Context & Available Globals

Inside your toggle files, these global objects are available:

### `shellRoot` — Global Shell State

| Property / Method               | Type       | Description                           |
|---------------------------------|------------|---------------------------------------|
| `shellRoot.wifiDevice`          | `var`      | The Quickshell `WifiDevice` object    |
| `shellRoot.wifiEnabled`         | `bool`     | WiFi enabled state                    |
| `shellRoot.wifiConnected`       | `bool`     | WiFi connected state                  |
| `shellRoot.wifiSsid`            | `string`   | Connected network SSID                |
| `shellRoot.wifiSignalLevel`     | `int`      | Signal strength (0–4)                 |
| `shellRoot.bluetoothEnabled`    | `bool`     | Bluetooth power state                 |
| `shellRoot.bluetoothConnected`  | `bool`     | Any BT device connected               |
| `shellRoot.powerProfile`        | `string`   | `"balanced"`, `"performance"`, etc.   |
| `shellRoot.setPowerProfile(p)`  | `function` | Sets the power profile                |
| `shellRoot.batteryPct`          | `int`      | Battery percentage (-1 if missing)    |
| `shellRoot.batteryStatus`       | `string`   | `"Charging"`, `"Discharging"`, etc.   |
| `shellRoot.icon(name)`          | `function` | Looks up an icon by Freedesktop name  |

### `expandedOverlay` — Expanded View State

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

## Part 5: File Naming & Discovery

### Naming Convention

Files **must** end with one of these suffixes to appear in the "Add a Control" popup:

| Suffix           | When to Use                                |
|------------------|--------------------------------------------|
| `*Toggle.qml`   | On/off toggles (WiFi, Bluetooth, DND)      |
| `*Slider.qml`   | Continuous controls (Brightness, Volume)    |
| `*Widget.qml`   | Large custom content (Media player)         |

> **Important:** Files with other names (e.g., `ExpandedHeader.qml`) are treated as utility components and won't appear in the control picker.

### Import Requirements

If your toggle uses `ExpandedHeader` or any other component from `components/reusables/`, you **must** add:

```qml
import "../reusables"
```

This is because toggles are loaded via `Loader` from `QuickSettings.qml`, and types in the `reusables/` directory aren't auto-resolved from the `toggles/` subdirectory.

### Layout Registration

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

## Part 6: Grid Sizing

| `colSpan × rowSpan` | Visual Shape        | Chrome Renders                   |
|----------------------|---------------------|----------------------------------|
| `1 × 1`             | Circle              | Icon only (centered)             |
| `2 × 1`             | Horizontal pill     | Icon + label side-by-side        |
| `2 × 2`             | Large card          | Icon + label (custom layout OK)  |
| `4 × 2`             | Full-width card     | Custom widget (e.g. media)       |

Users can cycle sizes in Edit Mode by tapping the toggle.

---

## Quick Reference — Copy-Paste Templates

### Minimal Toggle (14 lines)

```qml
import QtQuick

Item {
    property bool isSimpleToggle: true
    property string titleText: "My Toggle"
    property string iconSource: shellRoot.icon("my-icon-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: { /* your logic */ }
}
```

### Toggle with Expanded View

```qml
import QtQuick
import QtQuick.Layouts
import "../reusables"

Item {
    id: root
    property bool isSimpleToggle: true
    property string titleText: "My Toggle"
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
                    title: "My Toggle"
                    subtitle: root.isActive ? "On" : "Off"
                    iconSource: root.iconSource
                    isActive: root.isActive
                    activeColor: root.activeColor
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
