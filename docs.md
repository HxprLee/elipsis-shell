# Quickshell Hyprland UI

A sophisticated, feature-rich desktop shell for the Hyprland Wayland compositor, built using the Quickshell framework.

## Architecture

The project uses a centralized state pattern where `shell.qml` holds the "source of truth" for system states, while individual components react to these properties.

### Core Files

*   **`shell.qml`**: Entry point. Manages global state (notifications, dock logic, system monitoring, window tracking, session lock).
*   **`components/BottomBar.qml`**: Dynamic dock with smart auto-hide, swipe gestures (workspace switch, kill window, overlay), and context menus.
*   **`components/StatusBar.qml`**: Top bar providing time, workspaces, and system tray integration. Swiping down opens QuickSettings.
*   **`components/QuickSettings.qml`**: Dual-pane overlay (Notification Center & Control Center). Contains quick toggles, sliders, and media controls.
*   **`components/AppDrawer.qml`**: Full-screen application launcher with search, category filtering, and swipe gestures.
*   **`components/TaskManager.qml`**: Sophisticated window and workspace management. Provides live previews and drag-and-drop workspace assignment.
*   **`components/Lockscreen.qml`**: iOS/Windows 11 inspired lock screen. Features dynamic blur, large clock, swipe-to-unlock, and a PAM-backed numpad for authentication.
*   **`components/StatusCluster.qml`**: Unified component displaying Bluetooth, WiFi, and Battery status, shared across StatusBar and Lockscreen.

## Dependencies

*   **Framework**: Quickshell (QML + Wayland protocols).
*   **Compositor**: Hyprland (`Quickshell.Hyprland` IPC).
*   **Styling**: `breeze-dark` icons (with fallbacks).
*   **External CLI Tools**:
    *   `nmcli`: WiFi toggling.
    *   `bluetoothctl`: Bluetooth toggling.
    *   `awww`: Wallpaper querying.
    *   `busctl`: Brightness control (via `login1`).

## IPC Interfaces

The shell exposes `IpcHandler` targets for external control via Quickshell IPC.

### Target: `lock`
Controls the session lock screen.
*   `toggle()`: Toggles the lock state.
*   `lock()`: Activates the lock screen.
*   `unlock()`: Deactivates the lock screen.

### Target: `task_manager`
Controls the task switcher overlay.
*   `toggle()`: Toggles the task manager visibility.
*   `open()`: Opens the task manager.
*   `close()`: Closes the task manager.

---

## Control Center — Toggle System

The Control Center (`QuickSettings.qml`, right panel) uses a data-driven architecture where individual toggle files in `components/toggles/` provide **data and behavior**, while the shell provides **visual chrome**.

### Simple Toggle Protocol

Any `.qml` file placed in `components/toggles/` is auto-discoverable. To create a simple toggle, export these properties:

```qml
Item {
    property bool isSimpleToggle: true          // Required — marks this as a simple toggle
    property string titleText: "My Toggle"      // Label shown in 2-wide layouts
    property string iconSource: "icon-path"     // Freedesktop icon via shellRoot.icon()
    property bool isActive: false               // Controls active/inactive styling
    property color activeColor: Qt.rgba(...)    // Background color when active
    signal toggled()                            // Emitted on tap — wire your logic here
}
```

The shell reads these properties and renders the toggle chrome: circular badge for 1×1 slots, horizontal pill with icon + label for 2×1 slots, active color background, and click handling. The toggle file itself has **no visual output**.

**Example** — `BluetoothToggle.qml`:
```qml
Item {
    property bool isSimpleToggle: true
    property string titleText: "Bluetooth"
    property string iconSource: shellRoot.icon(qs.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
    property bool isActive: qs.bluetoothEnabled
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: qs.toggleBluetooth()
}
```

### Expanded View System

Toggles can opt into a **long-press expanded view** — a larger overlay that morphs out of the toggle's grid slot. This is used for toggles that need richer UI (e.g., Wi-Fi network list).

To add an expanded view, add these two properties alongside the simple toggle properties:

```qml
property bool hasExpandedView: true
property Component expandedComponent: Component {
    Item {
        // Your full expanded UI here.
        // The parent is sized by the shell (full panel width × 420px).
        // Use ColumnLayout with anchors.fill: parent for best results.
    }
}
```

**How it works:**
1.  User **long-presses** a toggle that has `hasExpandedView: true`.
2.  The shell records the toggle's position and size.
3.  An `expandedCard` rectangle is placed exactly over the toggle slot.
4.  The card **morphs** (animates position, size, and corner radius) from the small slot to a large centered overlay.
5.  The `expandedComponent` is loaded inside the card and fades in after the morph completes.
6.  Tapping outside the card morphs it back to the original slot and dismisses it.

### `ExpandedHeader` Component

**File:** `components/reusables/ExpandedHeader.qml`

A reusable header for expanded views. Provides a consistent look: icon badge, title, subtitle, optional trailing content, optional Material 3 switch, and a bottom divider.

#### Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `title` | `string` | `""` | Main heading text |
| `subtitle` | `string` | `""` | Secondary line (hidden when empty) |
| `iconSource` | `string` | `""` | Icon for the circular badge |
| `isActive` | `bool` | `false` | Controls active/inactive color states |
| `activeColor` | `color` | blue | Accent color for badge and switch |
| `showSwitch` | `bool` | `false` | Show a Material 3 toggle switch |
| `trailingContent` | `Item` | — | Slot for extra controls (e.g. refresh button) |

#### Signals

| Signal | Description |
|---|---|
| `switchToggled()` | Emitted when the Material 3 switch is tapped |

#### Usage — Minimal (no switch)

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

#### Usage — With switch and trailing content

```qml
ExpandedHeader {
    Layout.fillWidth: true
    title: "Wi-Fi"
    subtitle: root.isActive ? "Connected" : "Off"
    iconSource: root.iconSource
    isActive: root.isActive
    activeColor: root.activeColor
    showSwitch: true
    onSwitchToggled: root.toggled()

    trailingContent: Rectangle {
        width: 32; height: 32; radius: 16
        color: Qt.rgba(1, 1, 1, 0.1)
        // ... your button content
    }
}
```

### Grid Layout & Sizing

Toggles are arranged in a **4-column grid**. Each toggle specifies its size via `colSpan` and `rowSpan` in the layout JSON (`config/control_center_layout.json`):

| Size | `colSpan × rowSpan` | Visual Shape |
|---|---|---|
| Small circle | `1 × 1` | Icon only, fully round |
| Horizontal pill | `2 × 1` | Icon + label, pill-shaped |
| Large card | `2 × 2` | Custom content (e.g. media widget) |

The layout is persisted to `config/control_center_layout.json` and hot-reloaded on file changes.

### Edit Mode

Pressing **Edit** in the Control Center header enables edit mode:
*   **Tap** a toggle to cycle its size (`1×1` → `2×1` → `2×2` → `1×1`).
*   **Drag** toggles to reorder them in the grid.
*   **Remove** toggles via the delete button overlay.
*   **Add** new toggles from the "Add a Control" popup (auto-discovers all `.qml` files in `components/toggles/`).
*   Press **Done** to save the layout to disk.
