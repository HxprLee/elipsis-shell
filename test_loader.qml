import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

ApplicationWindow {
    width: 400
    height: 600
    visible: true

    Flickable {
        anchors.fill: parent
        contentHeight: innerCol.implicitHeight
        
        ColumnLayout {
            id: innerCol
            width: parent.width
            
            Loader {
                id: loader
                Layout.fillWidth: true
                active: true
                sourceComponent: comp
            }
        }
    }
    
    Component {
        id: comp
        ColumnLayout {
            width: loader.width
            Rectangle {
                Layout.fillWidth: true
                height: 100
                color: "red"
            }
        }
    }
    
    Timer {
        running: true
        interval: 1000
        onTriggered: {
            console.log("Loader height:", loader.height, "implicit:", loader.implicitHeight)
            console.log("innerCol height:", innerCol.height, "implicit:", innerCol.implicitHeight)
            Qt.quit()
        }
    }
}