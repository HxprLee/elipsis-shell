import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: popupWindow
    visible: false
    implicitWidth: 460
    implicitHeight: 450
    color: "transparent"
    anchors.top: true
    margins.top: slideOffset
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    property real slideOffset: -470
    Behavior on slideOffset {
        NumberAnimation { duration: 200; easing.type: Easing.OutExpo }
    }

    SequentialAnimation {
        id: hideAnim
        NumberAnimation { target: contentContainer; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutExpo }
        PropertyAction { target: popupWindow; property: "visible"; value: false }
    }

    WlrLayershell.keyboardFocus: WlrLayershell.None
    WlrLayershell.layer: WlrLayershell.Overlay

    Connections {
        target: shellRoot
        function onPanelOpenChanged() {
            if (shellRoot.panelOpen) {
                notificationQueue = []
                popupWindow.finishHide()
            }
        }
        function onPanelDragOffsetChanged() {
            if (shellRoot.panelDragOffset > 5) {
                notificationQueue = []
                popupWindow.finishHide()
            }
        }
    }

    property bool isActive: false
    property var notificationQueue: []
    property int stackCount: 0

    function show(n) {
        if (shellRoot.panelOpen) return;
        if (shellRoot.dndActive) return;

        let copy = notificationQueue.slice()
        copy.push(n)
        notificationQueue = copy
        stackCount = notificationQueue.length

        if (!isActive) {
            popupWindow.visible = true
            contentContainer.opacity = 1.0
            isActive = true
            Qt.callLater(() => { slideOffset = 40 })
        }
        autoHideTimer.restart()
    }

    function dismissTop() {
        if (notificationQueue.length > 0) {
            let n = notificationQueue[0]
            notificationServer.dismiss(n.id)
            let copy = notificationQueue.slice(1)
            notificationQueue = copy
            stackCount = notificationQueue.length
        }
        if (notificationQueue.length === 0) {
            finishHide()
        }
    }

    function finishHide() {
        slideOffset = -470
        isActive = false
        autoHideTimer.stop()
        hideAnim.start()
    }

    function finishImmediate() {
        popupWindow.visible = false
        isActive = false
        autoHideTimer.stop()
    }

    Timer {
        id: autoHideTimer
        interval: 4000
        onTriggered: {
            if (notificationQueue.length > 0) {
                let copy = notificationQueue.slice(1)
                notificationQueue = copy
                stackCount = notificationQueue.length
            }
            if (notificationQueue.length === 0) {
                finishHide()
            } else {
                autoHideTimer.restart()
            }
        }
    }

    property int cardSpacing: 4

    Item {
        id: contentContainer
        anchors.fill: parent
        opacity: 1.0

        StackCard {
            id: c0
            isTopCard: true
            y: 0
            notifData: popupWindow.notificationQueue.length > 0 ? popupWindow.notificationQueue[0] : null
            onDismiss: popupWindow.dismissTop()
            onTap: popupWindow.finishHide()
        }
        StackCard {
            id: c1
            y: c0.y + c0.height + cardSpacing + c1.entranceOffset
            notifData: popupWindow.notificationQueue.length > 1 ? popupWindow.notificationQueue[1] : null
            onDismiss: popupWindow.dismissTop()
            onTap: popupWindow.finishHide()
        }
        StackCard {
            id: c2
            y: c1.y + c1.height + cardSpacing + c2.entranceOffset
            notifData: popupWindow.notificationQueue.length > 2 ? popupWindow.notificationQueue[2] : null
            onDismiss: popupWindow.dismissTop()
            onTap: popupWindow.finishHide()
        }
        StackCard {
            id: c3
            y: c2.y + c2.height + cardSpacing + c3.entranceOffset
            notifData: popupWindow.notificationQueue.length > 3 ? popupWindow.notificationQueue[3] : null
            onDismiss: popupWindow.dismissTop()
            onTap: popupWindow.finishHide()
        }

        Rectangle {
            id: overflowBadge
            y: c3.y + c3.height + cardSpacing
            width: parent.width
            height: 24
            radius: 12
            color: Qt.rgba(0.2, 0.5, 1.0, 0.9)
            visible: popupWindow.stackCount > 4

            Text {
                anchors.centerIn: parent
                text: "+" + (popupWindow.stackCount - 4) + " more"
                color: "white"
                font.pixelSize: 12
                font.bold: true
            }
        }
    }
}
