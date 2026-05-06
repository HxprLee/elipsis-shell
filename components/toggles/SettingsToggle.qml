import QtQuick

// SettingsToggle.qml — System settings launcher (data-only, styled by the shell).

Item {
    property bool isSimpleToggle: true
    property string titleText: "Settings"
    property string iconSource: shellRoot.icon("preferences-system-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: console.log("Settings clicked")
}
