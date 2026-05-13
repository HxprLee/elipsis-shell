import QtQuick

// LockToggle.qml — Screen lock toggle (data-only, styled by the shell).

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Lock"
    property string iconSource: shellRoot.icon("system-lock-screen-symbolic")
    property bool isActive: false
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: console.log("Lock clicked")
}
