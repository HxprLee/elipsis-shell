import QtQuick

// CaffeineToggle.qml — Caffeine toggle (data-only, styled by the shell).

Item {
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Caffeine"
    property string iconSource: shellRoot.icon("system-suspend-inhibited-symbolic")
    property bool isActive: shellRoot.caffeineActive
    property color activeColor: Qt.rgba(1.0, 0.6, 0.2, 1.0) // Orange-ish for coffee
    signal toggled()
    onToggled: shellRoot.setCaffeine(!shellRoot.caffeineActive)
}
