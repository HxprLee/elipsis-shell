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
    property var availableSizes: undefined // Array of {colSpan, rowSpan}

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
        pressAndHoldInterval: 300

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

    // ── Click-to-Cycle Resize button (bottom-right) ──
    Item {
        id: resizeHandleItem
        width: 32; height: 32
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        z: 10
        
        scale: resizeArea.pressed ? 0.85 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }

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
            id: resizeArea
            anchors.fill: parent
            anchors.margins: -8

            onClicked: {
                let currentCs = editOverlay.currentColSpan
                let currentRs = editOverlay.currentRowSpan
                let newCs = currentCs
                let newRs = currentRs

                if (editOverlay.availableSizes && Array.isArray(editOverlay.availableSizes) && editOverlay.availableSizes.length > 0) {
                    // Find current index
                    let idx = -1;
                    for (let i = 0; i < editOverlay.availableSizes.length; i++) {
                        let size = editOverlay.availableSizes[i];
                        if (size.colSpan === currentCs && size.rowSpan === currentRs) {
                            idx = i;
                            break;
                        }
                    }
                    
                    // Cycle to next size, wrapping around
                    let nextIdx = (idx + 1) % editOverlay.availableSizes.length;
                    let nextSize = editOverlay.availableSizes[nextIdx];
                    newCs = nextSize.colSpan;
                    newRs = nextSize.rowSpan;
                } else {
                    // Fallback cycle logic
                    let isSlider = widgetSource.indexOf("Slider") !== -1
                    let isMedia = widgetSource.indexOf("Media") !== -1

                    if (isSlider) {
                        // Sliders: 2x1 -> 4x1 -> 2x1
                        if (currentCs === 2) newCs = 4;
                        else newCs = 2;
                        newRs = 1;
                    } else if (isMedia) {
                        // Media: 2x2 -> 4x2 -> 2x2
                        if (currentCs === 2) newCs = 4;
                        else newCs = 2;
                        newRs = 2;
                    } else {
                        // Default: 1x1 -> 2x1 -> 2x2 -> 1x2 -> 1x1
                        if (currentCs === 1 && currentRs === 1) {
                            newCs = 2; newRs = 1;
                        } else if (currentCs === 2 && currentRs === 1) {
                            newCs = 2; newRs = 2;
                        } else if (currentCs === 2 && currentRs === 2) {
                            newCs = 1; newRs = 2;
                        } else {
                            newCs = 1; newRs = 1;
                        }
                    }
                }

                if (newCs !== currentCs || newRs !== currentRs) {
                    editOverlay.resized(newCs, newRs)
                }
            }
        }
    }
}
