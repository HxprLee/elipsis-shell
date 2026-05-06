import QtQuick

// EditOverlay.qml — Encapsulates drag-to-reorder and drag-to-resize for Control Center widgets.
// Placed as a sibling of the widget background inside each delegate.

Item {
    id: editOverlay
    anchors.fill: parent
    visible: editMode

    // ── Required properties ──
    required property bool editMode       // controlPanel.editMode
    required property int itemIndex       // delegate index
    required property string widgetSource // model.source ("toggles/MediaWidget.qml" etc)
    required property int currentColSpan  // model.colSpan
    required property int currentRowSpan  // model.rowSpan

    // ── Signals ──
    signal resized(int newColSpan, int newRowSpan)
    signal dragStarted()
    signal dragFinished()
    signal removed()

    // ── Drag state ──
    property alias dragActive: dragArea.dragActive

    Drag.active: dragArea.dragActive
    Drag.keys: ["toggle"]
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    // Dimming overlay (matches iOS 18 jiggle mode)
    Rectangle {
        anchors.fill: parent
        radius: parent.parent.radius || 24
        color: Qt.rgba(1, 1, 1, 0.1)
        border.color: Qt.rgba(1, 1, 1, 0.3)
        border.width: 1
    }

    // ── Drag MouseArea ──
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.margins: 10 // Leave room for handles
        drag.target: dragActive ? editOverlay.parent : null
        drag.axis: Drag.XAndYAxis
        property bool dragActive: false

        onPressAndHold: {
            dragActive = true
            editOverlay.dragStarted()
        }
        onReleased: {
            if (dragActive) {
                dragActive = false
                editOverlay.Drag.drop()
                editOverlay.dragFinished()
            }
        }
    }

    // ── Remove button (top-left) ──
    Rectangle {
        width: 24; height: 24; radius: 12
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: -6
        anchors.leftMargin: -6
        color: Qt.rgba(0.9, 0.2, 0.2, 1.0)
        border.color: Qt.rgba(0, 0, 0, 0.3)
        border.width: 1
        z: 10

        Rectangle {
            width: 12; height: 2; radius: 1
            color: "white"
            anchors.centerIn: parent
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: editOverlay.removed()
        }
    }

    // ── Drag Resize handle (bottom-right) ──
    Item {
        width: 32; height: 32
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        z: 10

        // Visual curve for resize handle
        Canvas {
            anchors.fill: parent
            onPaint: {
                let ctx = getContext("2d")
                ctx.strokeStyle = "white"
                ctx.lineWidth = 3
                ctx.lineCap = "round"
                ctx.beginPath()
                // Draw a curve in the bottom right corner
                ctx.moveTo(12, 24)
                ctx.quadraticCurveTo(24, 24, 24, 12)
                ctx.stroke()
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8

            property real startX: 0
            property real startY: 0
            property int startColSpan: 1
            property int startRowSpan: 1

            onPressed: (mouse) => {
                startX = mouse.x
                startY = mouse.y
                startColSpan = editOverlay.currentColSpan
                startRowSpan = editOverlay.currentRowSpan
            }

            onPositionChanged: (mouse) => {
                let dx = mouse.x - startX
                let dy = mouse.y - startY
                
                // toggleGrid properties:
                // fixed width: 400 - 48 = 352
                // columnSpacing: 16
                // cellWidth: (352 - 3*16) / 4 = 76
                // step = 76 + 16 = 92
                let stepX = 92
                let stepY = 92 // same for height

                let newCs = Math.max(1, Math.min(4, startColSpan + Math.round(dx / stepX)))
                let newRs = Math.max(1, Math.min(4, startRowSpan + Math.round(dy / stepY)))

                // Enforce specific logic for some widgets to match iOS constraints
                let isSlider = widgetSource.indexOf("Slider") !== -1
                let isMedia = widgetSource.indexOf("Media") !== -1

                if (isSlider) {
                    newRs = 1 // Sliders always 1 row tall
                    newCs = Math.max(2, newCs) // at least 2 wide
                } else if (isMedia) {
                    newCs = Math.max(2, newCs)
                    newRs = Math.max(2, newRs)
                }

                if (newCs !== editOverlay.currentColSpan || newRs !== editOverlay.currentRowSpan) {
                    editOverlay.resized(newCs, newRs)
                }
            }
        }
    }
}
