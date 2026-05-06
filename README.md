# Elipsis Shell

An interactive, touch-oriented desktop/tablet shell built with [Quickshell](https://quickshell.outfox.dev/). Inspired by iOS, Plasma Mobile and Android.

## Features
- Adaptive Dock
- Gesture Navigation
- App Drawer
- Task Switcher
- Volume/Brightness OSD
- Customizable Control Center

### Prerequisites
- Qt6
- [Quickshell](https://quickshell.outfox.dev/) installed on your system (git release).

### Running
Clone the repository and copy the content inside to `.config/quickshell` then run

```bash
qs
```

## Creating Custom Toggles

To create custom toggle, create a new QML file in the `components/toggles/` directory. A simple on/off toggle can be implemented in as few as 14 lines of code:

```qml
// MyToggle.qml
Item {
    property bool isSimpleToggle: true
    property string titleText: "My Feature"
    property string iconSource: shellRoot.icon("my-icon-symbolic")
    property bool isActive: someSystemState
    property color activeColor: "#3498db"
    
    signal toggled()
    onToggled: toggleMyFeature()
}
```

More details in [Toggle Guide](TOGGLE_GUIDE.md).
