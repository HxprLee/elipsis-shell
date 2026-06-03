import QtQuick

// PowerToggle.qml — Power menu / shutdown (data-only, styled by the shell).

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Power"
    property string iconSource: shellRoot.icon("system-shutdown-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.9, 0.2, 0.2, 1.0)
    signal toggled()
    onToggled: {
        shellRoot.panelOpen = false
        shellRoot.powerMenuOpen = true
    }
}
