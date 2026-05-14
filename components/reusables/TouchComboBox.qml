import QtQuick
import QtQuick.Controls

ComboBox {
    id: control
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)

    background: Rectangle {
        implicitWidth: 160
        implicitHeight: 36
        color: control.activeFocus ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
        radius: 8
    }

    contentItem: Text {
        leftPadding: 16
        rightPadding: 16
        text: control.displayText
        font.pixelSize: 14
        font.bold: true
        color: "white"
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 12
        y: (control.height - height) / 2
        text: "▼"
        color: Qt.rgba(1, 1, 1, 0.5)
        font.pixelSize: 10
    }

    delegate: ItemDelegate {
        width: control.width
        height: 44
        contentItem: Text {
            text: modelData
            color: "white"
            font.pixelSize: 14
            font.bold: control.currentIndex === index
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            padding: 16
        }
        background: Rectangle {
            color: control.highlightedIndex === index ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            radius: 6
            anchors.fill: parent
            anchors.margins: 4
        }
    }

    popup: Popup {
        y: control.height + 6
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 250)
        padding: 4

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }

        background: Rectangle {
            color: Qt.rgba(0.12, 0.12, 0.15, 1.0)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
            radius: 8
        }
    }
}
