import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Menu {
    id: menuRoot
    
    property var model: []

    padding: 8

    background: MaterialSurface {
        implicitWidth: 200
        radius: 12
    }
    
    Instantiator {
        model: menuRoot.model
        onObjectAdded: (index, object) => menuRoot.insertItem(index, object)
        onObjectRemoved: (index, object) => menuRoot.removeItem(object)
        delegate: MenuItem {
            id: menuItem
            implicitWidth: 200 - 16 // Account for menu padding
            implicitHeight: 36
            text: modelData.text
            property bool isDestructive: modelData.isDestructive || false
            
            contentItem: RowLayout {
                spacing: 12
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
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
                    text: menuItem.text
                    color: menuItem.isDestructive ? "#ff4444" : "white"
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                }
            }

            background: Rectangle {
                radius: 8
                color: menuItem.highlighted ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                anchors.fill: parent
            }

            onTriggered: {
                if (modelData.action) modelData.action();
            }
        }
    }
}
