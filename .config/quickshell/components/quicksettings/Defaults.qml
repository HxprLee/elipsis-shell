pragma Singleton
import QtQuick

// Default single-page layout for the control center. Used by controlPanel
// when no saved pages are present in config/config.json, and by the
// "Reset layout" entry in the edit-mode menu.
//
// Held in a separate singleton so the layout list is not interleaved with
// the rest of QuickSettings.qml's 4000+ lines. To add a toggle to the
// default page, edit it here; the change applies on the user's next
// resetLayout() (or first boot with no saved pages).
//
// Format: a flat array of { source, colSpan, rowSpan } entries on a 4x8
// grid, packed top-to-bottom, left-to-right. GridLayout's row height is
// the max rowSpan in the row; an entry wraps to the next row when
// col + colSpan > 4.
QtObject {
    readonly property var layout: [
        {
            source: "toggles/NetworkToggle.qml",
            colSpan: 2,
            rowSpan: 1
        },
        {
            source: "toggles/BluetoothToggle.qml",
            colSpan: 2,
            rowSpan: 1
        },
        {
            source: "toggles/PowerProfileToggle.qml",
            colSpan: 2,
            rowSpan: 1
        },
        {
            source: "toggles/MediaWidget.qml",
            colSpan: 2,
            rowSpan: 2
        },
        {
            source: "toggles/BrightnessSlider.qml",
            colSpan: 2,
            rowSpan: 1
        },
        {
            source: "toggles/VolumeSlider.qml",
            colSpan: 2,
            rowSpan: 1
        },
        {
            source: "toggles/SettingsToggle.qml",
            colSpan: 1,
            rowSpan: 1
        },
        {
            source: "toggles/LockToggle.qml",
            colSpan: 1,
            rowSpan: 1
        },
        {
            source: "toggles/PowerToggle.qml",
            colSpan: 1,
            rowSpan: 1
        },
        {
            source: "toggles/DndToggle.qml",
            colSpan: 1,
            rowSpan: 1
        },
        {
            source: "toggles/CaffeineToggle.qml",
            colSpan: 1,
            rowSpan: 1
        }
    ]
}
