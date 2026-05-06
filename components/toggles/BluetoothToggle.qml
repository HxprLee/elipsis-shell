import QtQuick

// BluetoothToggle.qml — Bluetooth toggle (data-only, styled by the shell).

Item {
    property bool isSimpleToggle: true
    property string titleText: "Bluetooth"
    property string iconSource: shellRoot.icon(qs.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
    property bool isActive: qs.bluetoothEnabled
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    signal toggled()
    onToggled: qs.toggleBluetooth()
}
