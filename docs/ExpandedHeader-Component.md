# `ExpandedHeader` Component Reference

**File:** `components/ExpandedHeader.qml`

A drop-in header that gives your expanded view a consistent look: icon badge, title, subtitle, optional trailing content, optional toggle switch, and a divider line.

## Properties

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

## Signals

| Signal           | Emitted When                    |
|------------------|---------------------------------|
| `switchToggled()`| The switch is tapped            |
| `buttonClicked()`| The button is tapped            |

## Visual Layout

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

## Usage Variations

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
