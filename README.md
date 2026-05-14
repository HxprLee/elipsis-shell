# Elipsis Shell

An interactive, touch-oriented desktop/tablet shell built with [Quickshell](https://quickshell.outfox.dev/). Inspired by iOS, Plasma Mobile, Android and more mobile operating systems.

## Available Features
- Adaptive Dock
- Gesture Navigation
- App Drawer
- Task Switcher
- Volume/Brightness OSD
- Customizable Control Center

## Planned features
- Desktop widgets
- On-screen keyboard (OSK, could be a dedicated application)
- Live Status (kinda like One UI's Now Bar clone)
- Settings App (dedicated app)
- Customizable Status Bar
- Screenshot and annotation tool w/ integrated AI for OCR
- Optional AI assistant/chat
- Google's Circle to Search like feature
- More Lockscreen layouts (or a customizable lockscreen)
- Lockscreen widgets (probably uses desktop widgets)
- More navigation bar gestures
- Localization support 

### Prerequisites
- Qt6
- [Quickshell](https://quickshell.outfox.dev/) installed on your system (git release).

### Dependencies
Will update soon.

### Running
Clone the repository and copy the content inside to `.config/quickshell` then simply run

```bash
qs
```

## Creating Custom Toggles

To create a custom toggle, create a new QML file in the `components/toggles/` directory. A simple toggle can be implemented in as few as 12 lines of code:

```qml
// MyToggle.qml
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

More details in [Docs](docs.md).
