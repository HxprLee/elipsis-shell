import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: menuRoot
    width: 200
    height: menuCol.implicitHeight + 16
    color: Qt.rgba(0.1, 0.1, 0.15, 0.95)
    radius: 12
    border.color: Qt.rgba(1, 1, 1, 0.1)
    border.width: 1

    property alias model: repeater.model
    signal closed()

    Column {
        id: menuCol
        anchors.centerIn: parent
        spacing: 4
        width: parent.width - 16

        Repeater {
            id: repeater
            delegate: Button {
                id: menuBtn
                width: parent.width
                height: 36
                flat: true
                
                contentItem: RowLayout {
                    spacing: 12
                    Item {
                        width: 20; height: 20
                        visible: modelData.icon !== undefined && modelData.icon !== ""
                        Image {
                            anchors.centerIn: parent
                            width: 16; height: 16
                            source: modelData.icon || ""
                            sourceSize: Qt.size(24, 24)
                            visible: status === Image.Ready
                        }
                    }
                    Text {
                        text: modelData.text
                        color: modelData.isDestructive ? "#ff4444" : "white"
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                background: Rectangle {
                    radius: 8
                    color: menuBtn.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                }

                onClicked: {
                    if (modelData.action) modelData.action();
                    menuRoot.closed();
                }
            }
        }
    }
}
