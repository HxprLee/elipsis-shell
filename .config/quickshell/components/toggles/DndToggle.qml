import QtQuick

// DndToggle.qml — Do Not Disturb toggle (data-only, styled by the shell).

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "DND"
    property string iconSource: shellRoot.icon("notifications-disabled-symbolic")
    property bool isActive: shellRoot.dndActive
    property color activeColor: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: shellRoot.setDnd(!shellRoot.dndActive)
}
