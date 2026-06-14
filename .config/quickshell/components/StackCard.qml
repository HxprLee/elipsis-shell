import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property var notifData: null
    property bool isTopCard: false
    property real entranceOffset: 0

    signal dismiss()
    signal tap()

    width: parent ? parent.width : 460
    height: notifData !== null ? 80 : 0
    clip: true
    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutExpo }
    }

    SequentialAnimation {
        id: entranceAnim
        PropertyAction { target: root; property: "entranceOffset"; value: -80 }
        NumberAnimation { target: root; property: "entranceOffset"; to: 0; duration: 200; easing.type: Easing.OutExpo }
    }

    SequentialAnimation {
        id: fadeOutAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutExpo }
    }

    MaterialSurface {
        id: cardBg
        anchors.fill: parent
        radius: 16

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                width: 36; height: 36; radius: 8
                color: Qt.rgba(1, 1, 1, 0.1)
                Layout.alignment: Qt.AlignTop
                visible: root.notifData !== null && (root.notifData.appIcon !== "" || root.notifData.appName !== "")

                Text {
                    anchors.centerIn: parent
                    text: root.notifData && root.notifData.appName !== "" ? root.notifData.appName.charAt(0).toUpperCase() : "!"
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                    visible: !root.notifData || root.notifData.appIcon === ""
                }
                Image {
                    anchors.centerIn: parent
                    width: 24; height: 24
                    source: root.notifData && root.notifData.appIcon !== ""
                        ? (root.notifData.appIcon.startsWith("/") ? "file://" + root.notifData.appIcon : root.notifData.appIcon)
                        : ""
                    fillMode: Image.PreserveAspectFit
                    visible: source !== ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                Text {
                    text: root.notifData ? root.notifData.appName : ""
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 10
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                    elide: Text.ElideRight
                    visible: text !== ""
                    Layout.fillWidth: true
                }

                Text {
                    text: root.notifData ? root.notifData.summary : ""
                    color: "white"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.notifData ? root.notifData.body : ""
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: root.notifData ? root.notifData.body !== "" : false
                }
            }
        }

        MouseArea {
            anchors.fill: parent

            property real startX: 0
            property bool isDragging: false

            onPressed: (mouse) => {
                startX = mouse.x
                isDragging = false
            }
            onPositionChanged: (mouse) => {
                let dx = mouse.x - startX
                if (Math.abs(dx) > 5) isDragging = true
                if (isDragging) root.x = dx * 0.8
            }
            onReleased: (mouse) => {
                if (isDragging) {
                    let dx = mouse.x - startX
                    if (Math.abs(dx) > 60) {
                        root.x = (dx > 0 ? 500 : -500)
                        Qt.callLater(() => root.dismiss())
                    } else {
                        root.x = 0
                    }
                } else {
                    root.tap()
                }
            }
        }
    }

    onNotifDataChanged: {
        if (notifData !== null) {
            opacity = 1.0
            x = 0
            if (!isTopCard) {
                entranceAnim.start()
            }
        } else {
            entranceOffset = 0
            fadeOutAnim.start()
        }
    }
}
