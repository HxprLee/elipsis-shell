# Creating Custom Control Center Toggles

This section covers how to create custom toggles for the Control Center, from the simplest on/off toggle to complex widgets with full expanded UIs.

## Overview

The Control Center uses a **data-driven architecture**. Toggle files in `components/toggles/` provide **data and behavior only** — the shell renders the visual chrome (background, icon, label, click handling) automatically.

### How It Works

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

## Simple Toggle (No Expanded UI)

A simple toggle is a data-only QML `Item` with no visual content. The shell handles all rendering.

### Required Interface

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

### Minimal Example — `DndToggle.qml`

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

That's it — **12 lines**. No visual elements, no layouts. The shell does the rest.

### Dynamic State Example — `PowerProfileToggle.qml`

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

### Dynamic Subtitles

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

## Toggle with Expanded UI

For toggles that need a richer interface (network lists, detailed settings, etc.), you can add an **expanded view** that opens on long-press.

### Additional Properties

Add these alongside the simple toggle interface:

| Property             | Type        | Description                                           |
|----------------------|-------------|-------------------------------------------------------|
| `hasExpandedView`    | `bool`      | Must be `true` — enables long-press expansion         |
| `expandedComponent`  | `Component` | The QML component to render inside the expanded card  |
| `expandedHeight`     | `int`       | Optional. Hardcode the height of the expanded view. Use if `implicitHeight` fails to evaluate correctly (e.g. async lists). If omitted, UI scales to `implicitHeight` up to a max limit. |

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

## File Discovery & Registration

### Discovery via `isControlWidget`

Any `.qml` file placed in `components/toggles/` will be loaded. However, only files that export `isControlWidget: true` will appear. Files without this property (e.g., utility components) will be ignored.

```qml
Item {
    property bool isControlWidget: true  // ← Required to be recognized as toggle
    property string toggleName: "My Toggle"
    // ...
}
```

### Recommended Naming

While file names don't affect discovery, it's recommended to use these suffixes for readability:

| Suffix           | Convention                                 |
|------------------|--------------------------------------------|
| `*Toggle.qml`   | On/off toggles (WiFi, Bluetooth, DND)      |
| `*Slider.qml`   | Continuous controls (Brightness, Volume)    |
| `*Widget.qml`   | Large custom content (Media player)         |

### Import Requirements

If your toggle uses `ExpandedHeader` or any other component from `components/`, you **must** add:

```qml
import ".."
```

This is because toggles are loaded via `Loader` from `QuickSettings.qml`, and types in the parent `components/` directory aren't auto-resolved from the `toggles/` subdirectory.

### Layout Registration

After creating your file, add it to `config/control_center_layout.json`:

```json
{
    "source": "toggles/YourToggle.qml",
    "colSpan": 1,
    "rowSpan": 1
}
```

Or use **Edit Mode** (tap "Edit" in the Control Center header) → tap the **Add a Control** button to add your toggle from the picker.

---

## Grid Sizing

| `colSpan × rowSpan` | Visual Shape        | Chrome Renders                   |
|----------------------|---------------------|----------------------------------|
| `1 × 1`             | Circle              | Icon only (centered)             |
| `2 × 1`             | Horizontal pill     | Icon + label side-by-side        |
| `2 × 2`             | Large card          | Icon + label (custom layout OK)  |
| `4 × 2`             | Full-width card     | Custom widget (e.g. media)       |

Users can cycle sizes in Edit Mode by tapping the toggle.

### Restricting Sizes (`availableSizes`)

By default, the shell allows users to cycle through generic widget sizes in Edit Mode by tapping the corner resize handle. To take control of which sizes your toggle supports, export the `availableSizes` property as an array of objects. The shell will cycle exactly through these sizes when the resize button is tapped:

```qml
property var availableSizes: [
    { colSpan: 2, rowSpan: 2 }, // 2x2 Square
    { colSpan: 4, rowSpan: 2 }  // 4x2 Full width
]
```

### Responsive Layouts

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

## Quick Reference — Copy-Paste Templates

### Minimal Toggle

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

### Toggle with Expanded View

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
