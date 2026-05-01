import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: popupWindow
    visible: false
    implicitHeight: 600
    color: "transparent"
    anchors.top: true
    anchors.left: true
    anchors.right: true
    margins.top: 40
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    Component.onCompleted: {
        WlrLayershell.layer = 3 // Overlay layer
    }

    // Auto-dismiss when Quick Settings opens or is dragged
    Connections {
        target: shellRoot
        function onPanelOpenChanged() { if (shellRoot.panelOpen) popupWindow.hide() }
        function onPanelDragOffsetChanged() { if (shellRoot.panelDragOffset > 5) popupWindow.hide() }
    }

    property bool isActive: false
    property int nid: -1
    property string appName: ""
    property string appIcon: ""
    property string summary: "Notification"
    property string body: ""

    function show(n) {
        if (shellRoot.panelOpen) return;

        nid = n.id
        appName = n.appName
        appIcon = n.appIcon ?? ""
        summary = n.summary
        body = n.body
        pill.xOffset = 0
        pill.yOffset = 0
        
        popupWindow.visible = true
        isActive = true
        autoHideTimer.restart()
        slideOutTimer.stop()
    }

    function hide() {
        isActive = false
        autoHideTimer.stop()
        slideOutTimer.start()
    }

    Timer {
        id: autoHideTimer
        interval: 4000
        onTriggered: hide()
    }

    Timer {
        id: slideOutTimer
        interval: 600
        onTriggered: popupWindow.visible = false
    }

    Item {
        id: container
        anchors.fill: parent

        Rectangle {
            id: pill
            width: 400
            height: Math.max(72, textCol.implicitHeight + 36)
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 28
            color: Qt.rgba(0.1, 0.1, 0.15, 0.95)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1

            property real xOffset: 0
            property real yOffset: 0
            x: (parent.width - width) / 2 + xOffset
            y: (popupWindow.isActive ? 10 : -height - 50) + yOffset

            Behavior on y {
                enabled: !swipeArea.isDragging
                NumberAnimation { duration: 500; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            Behavior on x {
                enabled: !swipeArea.isDragging
                NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Rectangle {
                    width: 44; height: 44; radius: 12
                    color: Qt.rgba(1, 1, 1, 0.1)
                    Layout.alignment: Qt.AlignTop
                    Text {
                        anchors.centerIn: parent
                        text: popupWindow.appName !== "" ? popupWindow.appName.charAt(0).toUpperCase() : "!"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        visible: popupWindow.appIcon === ""
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 32; height: 32
                        source: popupWindow.appIcon !== "" && popupWindow.appIcon.startsWith("/") ? "file://" + popupWindow.appIcon : ""
                        fillMode: Image.PreserveAspectFit
                        visible: source !== ""
                    }
                }

                ColumnLayout {
                    id: textCol
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 4

                    Text {
                        id: summaryText
                        text: popupWindow.summary
                        color: "white"
                        font.pixelSize: 15
                        font.bold: true
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Text {
                        id: bodyText
                        text: popupWindow.body
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        visible: popupWindow.body !== ""
                    }
                }
            }

            MouseArea {
                id: swipeArea
                anchors.fill: parent
                property real startX: 0
                property real startY: 0
                property bool isDragging: false
                onPressed: (mouse) => {
                    startX = mouse.x
                    startY = mouse.y
                    isDragging = false
                    autoHideTimer.stop()
                }
                onPositionChanged: (mouse) => {
                    let dx = mouse.x - startX
                    let dy = mouse.y - startY
                    isDragging = true
                    if (Math.abs(dx) > Math.abs(dy)) {
                        pill.xOffset = dx * 0.8
                    } else if (dy < 0) {
                        pill.yOffset = dy * 0.5
                    }
                }
                onReleased: (mouse) => {
                    if (isDragging) {
                        let dx = mouse.x - startX
                        let dy = mouse.y - startY
                        if (dy < -30 && Math.abs(dy) > Math.abs(dx)) {
                            popupWindow.hide()
                        } else if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy)) {
                            if (popupWindow.nid !== -1) {
                                notificationServer.dismiss(popupWindow.nid)
                            }
                            pill.xOffset = (dx > 0 ? 500 : -500)
                            popupWindow.hide()
                        } else {
                            pill.xOffset = 0
                            pill.yOffset = 0
                            popupWindow.isActive = true
                            autoHideTimer.restart()
                        }
                    } else {
                        popupWindow.hide()
                    }
                }
            }
        }
    }
}
