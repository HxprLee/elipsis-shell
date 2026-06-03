import QtQuick
import QtQuick.Layouts

Rectangle {
    id: control

    property string title: ""
    property string subtitle: ""
    property color subtitleColor: "white"
    property string iconSource: ""
    property real iconOpacity: 1.0
    property bool showCheckmark: false
    property bool showLock: false

    property bool isExpanded: false
    property Component expandedComponent: null

    // Increased padding: base height is slightly larger
    property int baseHeight: subtitle !== "" ? 54 : 40

    signal clicked

    Layout.fillWidth: true
    Layout.preferredHeight: isExpanded ? implicitHeight : baseHeight
    implicitHeight: contentColumn.implicitHeight + (isExpanded ? 16 : 0)
    radius: 6
    color: hoverArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
    clip: true

    Behavior on Layout.preferredHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutExpo
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        RowLayout {
            id: mainRow
            Layout.fillWidth: true
            Layout.preferredHeight: control.baseHeight
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 10

            Image {
                Layout.alignment: Qt.AlignVCenter
                sourceSize: Qt.size(20, 20)
                source: control.iconSource
                opacity: control.iconOpacity
                visible: control.iconSource !== ""
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: control.title
                    color: "white"
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                Text {
                    visible: control.subtitle !== ""
                    text: control.subtitle
                    color: control.subtitleColor
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                }
            }

            Image {
                visible: control.showCheckmark
                Layout.alignment: Qt.AlignVCenter
                sourceSize: Qt.size(16, 16)
                source: typeof shellRoot !== "undefined" ? shellRoot.icon("object-select-symbolic") : ""
            }

            Image {
                visible: control.showLock
                Layout.alignment: Qt.AlignVCenter
                sourceSize: Qt.size(14, 14)
                source: typeof shellRoot !== "undefined" ? shellRoot.icon("system-lock-screen-symbolic") : ""
                opacity: 0.5
            }
        }

        Loader {
            id: expandedLoader
            Layout.fillWidth: true
            active: control.isExpanded && control.expandedComponent !== null
            sourceComponent: control.expandedComponent
            visible: active
        }
    }

    MouseArea {
        id: hoverArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: control.baseHeight
        hoverEnabled: true
        onClicked: control.clicked()
    }
}
