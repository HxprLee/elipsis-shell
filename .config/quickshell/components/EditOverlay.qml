import QtQuick

// EditOverlay.qml — Encapsulates drag-to-reorder and drag-to-resize for Control Center widgets.
// Placed as a sibling of the widget background inside each delegate.

Item {
    id: editOverlay
    visible: editMode

    // ── Required properties ──
    required property bool editMode       // controlPanel.editMode
    required property int itemIndex       // delegate index
    required property string widgetSource // model.source ("toggles/MediaWidget.qml" etc)
    required property int currentColSpan  // model.colSpan
    required property int currentRowSpan  // model.rowSpan
    property var availableSizes: undefined // Array of {colSpan, rowSpan}
    property real widgetRadius: 24

    // ── Signals ──
    signal resized(int newColSpan, int newRowSpan)
    signal dragStarted(real grabOffsetX, real grabOffsetY)
    signal dragMoved(real globalX, real globalY)
    signal dragFinished()
    signal removed()

    // ── Drag state ──
    property alias dragActive: dragArea.dragActive

    // Dimming overlay (matches iOS 18 jiggle mode)
    Rectangle {
        anchors.fill: parent
        radius: editOverlay.widgetRadius
        color: Qt.rgba(1, 1, 1, 0.1)
        border.color: Qt.rgba(1, 1, 1, 0.3)
        border.width: 1
    }

    // ── Drag MouseArea ──
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.margins: 10 // Leave room for handles
        property bool dragActive: false
        pressAndHoldInterval: 300
        property real grabX: 0
        property real grabY: 0

        onPressAndHold: {
            dragActive = true
            grabX = mouseX
            grabY = mouseY
            // Calculate grab offset relative to editOverlay
            let offsetX = mouseX + dragArea.anchors.margins
            let offsetY = mouseY + dragArea.anchors.margins
            editOverlay.dragStarted(offsetX, offsetY)
        }
        onPositionChanged: {
            if (dragActive) {
                let p = dragArea.mapToItem(null, mouseX, mouseY)
                editOverlay.dragMoved(p.x, p.y)
            }
        }
        onReleased: {
            if (dragActive) {
                dragActive = false
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
            // Anchor to the entire editOverlay (not just the 32x32 visual
            // handle) so a vertical drag stays grabbed while moving up
            // into the widget body. Previously anchored to
            // resizeHandleItem with margins: -8 → 48x48 grab zone, but
            // the row step is ~116px; any vertical drag past 48px exited
            // the grab zone and the press was released mid-drag,
            // visibly "dropping" the resize.
            anchors.fill: parent
            z: 20
            preventStealing: true

            property real startX: 0
            property real startY: 0
            property int startColSpan: 1
            property int startRowSpan: 1
            property bool isDraggingSize: false
            // Computed in onPressed from availableSizes (or [1,4] if
            // absent). Read in onPositionChanged to clamp the live
            // drag target. Per-press recomputation handles the case
            // where availableSizes changes mid-session.
            property int maxAvailCs: 4
            property int maxAvailRs: 4

            onPressed: (mouse) => {
                let globalPos = mapToItem(null, mouse.x, mouse.y)
                startX = globalPos.x
                startY = globalPos.y
                startColSpan = editOverlay.currentColSpan
                startRowSpan = editOverlay.currentRowSpan
                isDraggingSize = false

                // Compute clamping bounds from availableSizes if declared,
                // else fall back to [1, 4]. Without this, a simple toggle
                // with no availableSizes (Bluetooth, Network, Caffeine)
                // could be dragged to 1x4 or 4x1 — sizes it never
                // intended to support — because onPositionChanged
                // clamps to the hardcoded [1, 4] range. With this, the
                // max comes from the widget's own declaration.
                let sizeArr = editOverlay.availableSizes;
                maxAvailCs = 4;
                maxAvailRs = 4;
                if (sizeArr && Array.isArray(sizeArr) && sizeArr.length > 0) {
                    maxAvailCs = 1;
                    maxAvailRs = 1;
                    for (let i = 0; i < sizeArr.length; i++) {
                        let s = sizeArr[i];
                        if (s.colSpan !== undefined) maxAvailCs = Math.max(maxAvailCs, s.colSpan);
                        if (s.rowSpan !== undefined) maxAvailRs = Math.max(maxAvailRs, s.rowSpan);
                    }
                }
            }

            onPositionChanged: (mouse) => {
                let globalPos = mapToItem(null, mouse.x, mouse.y)
                let dx = globalPos.x - startX
                let dy = globalPos.y - startY
                
                if (!isDraggingSize && (Math.abs(dx) > 15 || Math.abs(dy) > 15)) {
                    isDraggingSize = true
                }

                if (!isDraggingSize) return;

                // Grid cell step size is derived: (panel width - margins) / cols + spacing
                // We approximate by parent.width / 4 since the grid is 4 columns
                let stepX = (editOverlay.parent ? editOverlay.parent.width : 400) / 4 + 16
                let stepY = stepX

                let targetCs = startColSpan + dx / stepX
                let targetRs = startRowSpan + dy / stepY

                // Clamp to widget-declared available sizes (computed in
                // onPressed) instead of the hardcoded [1,4]. Simple
                // toggles without availableSizes cap at the [1,4]
                // fallback they fall back to.
                let newCs = Math.max(1, Math.min(maxAvailCs, Math.round(targetCs)))
                let newRs = Math.max(1, Math.min(maxAvailRs, Math.round(targetRs)))

                if (newCs !== editOverlay.currentColSpan || newRs !== editOverlay.currentRowSpan) {
                    editOverlay.resized(newCs, newRs)
                }
            }

            onReleased: {
                if (!isDraggingSize) return;
                isDraggingSize = false;

                let targetCs = editOverlay.currentColSpan
                let targetRs = editOverlay.currentRowSpan
                let newCs = targetCs
                let newRs = targetRs

                if (editOverlay.availableSizes && Array.isArray(editOverlay.availableSizes) && editOverlay.availableSizes.length > 0) {
                    let closestDist = Infinity;
                    let bestSize = editOverlay.availableSizes[0];
                    
                    for (let i = 0; i < editOverlay.availableSizes.length; i++) {
                        let size = editOverlay.availableSizes[i];
                        let dist = Math.pow(size.colSpan - targetCs, 2) + Math.pow(size.rowSpan - targetRs, 2);
                        if (dist < closestDist) {
                            closestDist = dist;
                            bestSize = size;
                        }
                    }
                    newCs = bestSize.colSpan;
                    newRs = bestSize.rowSpan;
                } else {
                    let isSlider = widgetSource.indexOf("Slider") !== -1
                    let isMedia = widgetSource.indexOf("Media") !== -1

                    if (isSlider) {
                        newRs = 1 
                        newCs = Math.max(2, targetCs) 
                    } else if (isMedia) {
                        newCs = Math.max(2, targetCs)
                        newRs = Math.max(2, targetRs)
                    } else {
                        newCs = Math.min(2, targetCs)
                        newRs = Math.min(2, targetRs)
                    }
                }

                if (newCs !== editOverlay.currentColSpan || newRs !== editOverlay.currentRowSpan) {
                    editOverlay.resized(newCs, newRs)
                }
            }
            
            onClicked: {
                if (isDraggingSize) return;
                
                let currentCs = editOverlay.currentColSpan
                let currentRs = editOverlay.currentRowSpan
                let newCs = currentCs
                let newRs = currentRs

                if (editOverlay.availableSizes && Array.isArray(editOverlay.availableSizes) && editOverlay.availableSizes.length > 0) {
                    let idx = -1;
                    for (let i = 0; i < editOverlay.availableSizes.length; i++) {
                        let size = editOverlay.availableSizes[i];
                        if (size.colSpan === currentCs && size.rowSpan === currentRs) {
                            idx = i;
                            break;
                        }
                    }
                    let nextIdx = (idx + 1) % editOverlay.availableSizes.length;
                    let nextSize = editOverlay.availableSizes[nextIdx];
                    newCs = nextSize.colSpan;
                    newRs = nextSize.rowSpan;
                } else {
                    let isSlider = widgetSource.indexOf("Slider") !== -1
                    let isMedia = widgetSource.indexOf("Media") !== -1

                    if (isSlider) {
                        if (currentCs === 2) newCs = 4; else newCs = 2;
                        newRs = 1;
                    } else if (isMedia) {
                        if (currentCs === 2) newCs = 4; else newCs = 2;
                        newRs = 2;
                    } else {
                        if (currentCs === 1 && currentRs === 1) { newCs = 2; newRs = 1; }
                        else if (currentCs === 2 && currentRs === 1) { newCs = 2; newRs = 2; }
                        else if (currentCs === 2 && currentRs === 2) { newCs = 1; newRs = 2; }
                        else { newCs = 1; newRs = 1; }
                    }
                }

                if (newCs !== currentCs || newRs !== currentRs) {
                    editOverlay.resized(newCs, newRs)
                }
            }
        }
    }
}
