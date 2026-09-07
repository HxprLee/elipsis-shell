import QtQuick
import "services"

// DndToggle.qml — Do Not Disturb toggle (data-only, styled by the shell).

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "DND"
    property string iconSource: Icons.icon("notifications-disabled-symbolic")
    property bool isActive: Notifications.dndActive
    property color activeColor: Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: Notifications.setDnd(!Notifications.dndActive)
}
