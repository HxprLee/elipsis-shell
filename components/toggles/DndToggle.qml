import QtQuick

// DndToggle.qml — Do Not Disturb toggle (data-only, styled by the shell).

Item {
    property bool isSimpleToggle: true
    property string titleText: "DND"
    property string iconSource: shellRoot.icon("notifications-disabled-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: console.log("DND clicked")
}
