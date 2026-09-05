import QtQuick
import Quickshell.Io

// SettingsToggle.qml — System settings launcher (data-only, styled by the shell).

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Settings"
    property string iconSource: shellRoot.icon("preferences-system-symbolic")
    property bool isActive: false
    property color activeColor: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()

    Process {
        id: settingsProc
        command: ["sh", "-c", "hyprctl dispatch exec gnome-control-center || hyprctl dispatch exec systemsettings5 || hyprctl dispatch exec xfce4-settings-manager"]
        running: false
    }

    onToggled: settingsProc.running = true
}
