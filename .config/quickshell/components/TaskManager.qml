import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: root
    visible: shellRoot.switcherOpen
    color: "transparent"

    function sanitizeAddr(addr) {
        if (!addr) return "";
        return addr.toString().replace(/[^0-9a-fA-Fx]/g, "");
    }

    function getScreen() {
        return root.screen || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
    }

    property var screenDimensions: {
        let s = root.getScreen();
        return s ? { width: s.width, height: s.height } : { width: 1920, height: 1080 };
    }

    property real monitorRatio: {
        let d = screenDimensions;
        return d.height > 0 ? d.width / d.height : 1.778;
    }

    property int viewMode: 0 // 0: Windows, 1: Workspaces
    signal forceResetDrag()
    onScreenChanged: refreshScreenDims()
    property bool _screenRefreshQueued: false
    function refreshScreenDims() {
        // Force re-evaluation of screenDimensions when screen changes
        if (_screenRefreshQueued) return;
        _screenRefreshQueued = true;
        Qt.callLater(() => { _screenRefreshQueued = false; screenDimensions = ({}); });
    }
    Connections {
        target: shellRoot
        function onSwitcherOpenChanged() {
            // Background blur is managed globally by shellRoot
        }
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    WlrLayershell.layer: WlrLayershell.Overlay

    // --- Base Tinted Background (Always Visible) ---
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.05)
    }

    Image {
        id: bgBlur
        anchors.fill: parent
        source: shellRoot.blurredWallpaperPath
        cache: false
        fillMode: Image.PreserveAspectCrop
        
        Connections {
            target: shellRoot
            function onBlurVersionChanged() {
                let s = bgBlur.source
                bgBlur.source = ""
                bgBlur.source = s
            }
        }
        
        visible: shellRoot.usePrecomputedBlur && shellRoot.staticBlurEnabled
        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)
        }
    }

    // --- Background Dim (Fallback) ---
    Rectangle {
        id: bg
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        opacity: root.visible && !shellRoot.usePrecomputedBlur ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: shellRoot.switcherOpen = false
        }
    }

    // --- Switcher Content ---
    Item {
        id: content
        anchors.fill: parent
        opacity: root.visible ? 1.0 : 0.0
        scale: root.visible ? 1.0 : 1.1

        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutExpo } }

        // --- View Mode Toggle ---
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 40
            spacing: 12
            z: 100

            Repeater {
                model: ["Windows", "Workspaces"]
                delegate: Button {
                    text: modelData
                    flat: true
                    
                    background: Rectangle {
                        implicitWidth: 120
                        implicitHeight: 40
                        radius: 20
                        color: root.viewMode === index ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: root.viewMode === index ? Qt.rgba(1, 1, 1, 0.3) : "transparent"
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 14
                        font.bold: root.viewMode === index
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.viewMode = index
                }
            }
        }

        // --- Top Workspace Row (for drag and drop) ---
        Row {
            id: workspaceRow
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 40
            spacing: 16
            visible: root.viewMode === 0
            z: 90

            Repeater {
                model: (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : []
                delegate: DropArea {
                    id: dropArea
                    height: (200 / root.monitorRatio) - 20
                    width: height * root.monitorRatio
                    keys: ["window-address", "text/plain", "text"]
                    
                    property var workspace: modelData
                    
                    // Interaction effects matching workspace cards
                    scale: dropArea.containsDrag ? 1.05 : (rowMouse.pressed ? 0.98 : (rowMouse.containsMouse ? 1.02 : 1.0))
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    Rectangle {
                        id: wsRowPreviewBg
                        anchors.fill: parent
                        radius: 14
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.color: dropArea.containsDrag ? "white" : (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === workspace.id ? "white" : Qt.rgba(1, 1, 1, 0.15))
                        border.width: (dropArea.containsDrag || (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === workspace.id)) ? 2 : 1
                        clip: true
                        
                        // Wallpaper background with rounded clipping
                        Rectangle { id: rowMask; anchors.fill: parent; radius: 14; visible: false }
                        Image {
                            id: rowWallpaperImg
                            anchors.fill: parent
                            source: shellRoot.wallpaperPath ? "file://" + shellRoot.wallpaperPath : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }
                        OpacityMask {
                            anchors.fill: parent
                            source: rowWallpaperImg
                            maskSource: rowMask
                            opacity: 0.5
                            visible: rowWallpaperImg.status === Image.Ready
                        }

                        // Desktop Preview
                        Item {
                            id: rowDesktopPreview
                            anchors.fill: parent
                            anchors.margins: 6

                            property real monW: root.screenDimensions.width
                            property real monH: root.screenDimensions.height
                            property real scale: Math.min(width / monW, height / monH)

                            Rectangle {
                                anchors.centerIn: parent
                                width: rowDesktopPreview.monW * rowDesktopPreview.scale
                                height: rowDesktopPreview.monH * rowDesktopPreview.scale
                                color: "transparent"

                                Repeater {
                                    model: workspace.toplevels.values
                                    delegate: Item {
                                        property var ipc: modelData.lastIpcObject
                                        x: (ipc && ipc.at && ipc.at.length >= 2) ? ipc.at[0] * rowDesktopPreview.scale : 0
                                        y: (ipc && ipc.at && ipc.at.length >= 2) ? ipc.at[1] * rowDesktopPreview.scale : 0
                                        width: (ipc && ipc.size && ipc.size.length >= 2) ? ipc.size[0] * rowDesktopPreview.scale : 100 * rowDesktopPreview.scale
                                        height: (ipc && ipc.size && ipc.size.length >= 2) ? ipc.size[1] * rowDesktopPreview.scale : 100 * rowDesktopPreview.scale

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 2 * rowDesktopPreview.scale
                                            color: Qt.rgba(1, 1, 1, 0.2)
                                            border.color: Qt.rgba(1, 1, 1, 0.3)
                                            border.width: 1
                                            clip: true

                                            ScreencopyView {
                                                anchors.fill: parent
                                                captureSource: modelData.wayland
                                                live: true
                                                visible: hasContent
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Workspace ID indicator overlay
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 26; height: 18; radius: 4
                            color: Qt.rgba(0, 0, 0, 0.6)
                            Text {
                                anchors.centerIn: parent
                                text: workspace.id
                                color: "white"; font.pixelSize: 10; font.bold: true
                            }
                        }
                    }

                    onDropped: (drop) => {
                        console.log("DROP EVENT FIRED!");
                        
                        let addr = "";
                        if (drop.source && drop.source.windowAddr) {
                            addr = drop.source.windowAddr;
                        } else if (drop.hasText && drop.text !== "") {
                            addr = drop.text;
                        }
                        
                        if (addr) {
                            let finalAddr = addr.toString();
                            if (!finalAddr.startsWith("address:")) {
                                finalAddr = "address:" + finalAddr;
                            }
                            let safeAddr = root.sanitizeAddr(finalAddr);
                            
                            console.log("SUCCESS: Moving window " + safeAddr + " to workspace " + workspace.id);
                            Hyprland.dispatch("hl.dsp.window.move({ workspace = " + workspace.id + ", window = '" + safeAddr + "', follow = false })");
                            drop.accept(Qt.MoveAction);
                        } else {
                            console.log("ERROR: Drop had no payload. Source exists: " + !!drop.source);
                        }
                        
                        Qt.callLater(root.forceResetDrag);
                    }
                    
                    onEntered: (drag) => {
                        console.log("DRAG ENTERED workspace " + workspace.id);
                        drag.accept(); // Explicitly accept to be safe
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspace.id + " })");
                            closeTimer.restart();
                        }
                    }
                }
            }
        }

        // --- All Windows View ---
        GridView {
            id: windowGrid
            anchors.fill: parent
            anchors.topMargin: 160
            anchors.bottomMargin: 100
            visible: root.viewMode === 0
            
            layoutDirection: Qt.RightToLeft
            flow: GridView.FlowTopToBottom
            cellWidth: 420
            cellHeight: 340
            
            leftMargin: 40
            rightMargin: 40
            
            model: (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : []
            clip: false

            add: Transition {
                NumberAnimation { property: "scale"; from: 0; to: 1; duration: 400; easing.type: Easing.OutBack }
            }
            
            remove: Transition {
                NumberAnimation { property: "scale"; to: 0; duration: 200 }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
            }

            // Background tap to dismiss
            TapHandler {
                onTapped: shellRoot.switcherOpen = false
            }

            delegate: Item {
                width: windowGrid.cellWidth
                height: windowGrid.cellHeight

                property var toplevel: modelData
                
                property string windowAddr: {
                    if (toplevel.lastIpcObject && toplevel.lastIpcObject.address) {
                        return toplevel.lastIpcObject.address;
                    }
                    if (toplevel.address) {
                        let addr = toplevel.address;
                        if (typeof addr === "number") return "0x" + addr.toString(16);
                        return addr.toString();
                    }
                    return "";
                }

                property real windowWidth: (toplevel.lastIpcObject && toplevel.lastIpcObject.size) ? (toplevel.lastIpcObject.size[0] || 1920) : 1920
                property real windowHeight: (toplevel.lastIpcObject && toplevel.lastIpcObject.size) ? (toplevel.lastIpcObject.size[1] || 1080) : 1080
                property real windowRatio: Math.max(0.5, Math.min(2.0, windowWidth / windowHeight))
                
                property real targetWidth: (windowRatio > 1.0) ? (windowGrid.cellWidth - 40) : (windowGrid.cellHeight - 100) * windowRatio
                property real targetHeight: (windowRatio > 1.0) ? (windowGrid.cellWidth - 40) / windowRatio : (windowGrid.cellHeight - 100)

                property string appIcon: {
                    let identifiers = [];
                    let ipc = toplevel.lastIpcObject;
                    if (ipc) {
                        if (ipc.class) identifiers.push(ipc.class);
                        if (ipc.initialClass) identifiers.push(ipc.initialClass);
                    }
                    let wcls = (toplevel.initialClass || toplevel.appId || (toplevel.wayland ? toplevel.wayland.appId : "") || "");
                    if (wcls) identifiers.push(wcls);

                    for (let id of identifiers) {
                        let entry = DesktopEntries.heuristicLookup(id);
                        if (entry && entry.icon) return (entry.icon.startsWith("/") ? "file://" + entry.icon : "image://icon/" + entry.icon);
                    }
                    
                    // Fallback to basic image lookup if heuristic fails
                    let appId = toplevel.appId || toplevel.initialClass || "";
                    return appId !== "" ? "image://icon/" + appId : "";
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    // Drag configuration
                    property bool dragEnabled: false
                    drag.target: dragEnabled ? card : null
                    drag.axis: Drag.XAndYAxis

                    Timer {
                        id: holdTimer
                        interval: 350
                        onTriggered: {
                            if (cardMouse.pressed) {
                                cardMouse.dragEnabled = true;
                                // Center card on touch point
                                card.x = cardMouse.mouseX - card.width / 2
                                card.y = cardMouse.mouseY - card.height / 2
                                // Visual feedback for hold
                                hapticsTimer.start();
                            }
                        }
                    }
                    
                    Timer { id: hapticsTimer; interval: 50 } // Placeholder for feedback

                    property real startY: 0
                    property real startX: 0
                    property real initialY: 0
                    property bool directionLocked: false
                    property bool isVertical: false
                    property real startTime: 0

                    onPressed: (mouse) => {
                        startY = mouse.y
                        startX = mouse.x
                        initialY = cardTranslate.y
                        startTime = Date.now()
                        directionLocked = false
                        isVertical = false
                        dragEnabled = false
                        holdTimer.start()
                        snapBackAnim.stop()
                    }

                    
                    Timer {
                        id: resetDragTimer
                        interval: 200 // Slightly longer to be safe
                        onTriggered: cardMouse.dragEnabled = false
                    }

                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            let dy = mouse.y - startY
                            let dx = mouse.x - startX

                            if (!dragEnabled && (Math.abs(dy) > 15 || Math.abs(dx) > 15)) {
                                holdTimer.stop()
                            }
                            
                            if (!dragEnabled && !directionLocked) {
                                if (Math.abs(dy) > 10 || Math.abs(dx) > 10) {
                                    directionLocked = true
                                    isVertical = Math.abs(dy) > Math.abs(dx)
                                    // If moving horizontally, let the GridView steal the touch
                                    if (!isVertical) cardMouse.preventStealing = false
                                    else cardMouse.preventStealing = true
                                }
                            }

                            if (isVertical) {
                                let totalY = initialY + dy
                                if (totalY < 0) cardTranslate.y = totalY
                                else cardTranslate.y = totalY * 0.2
                            }
                        }
                    }

                    function handleRelease() {
                        holdTimer.stop()
                        // Reset card position if it was being dragged
                        if (dragEnabled) {
                            card.Drag.drop()
                            card.x = (parent.width - card.width) / 2
                            card.y = (parent.height - card.height) / 2
                            resetDragTimer.restart()
                        } else {
                            dragEnabled = false
                        }

                        if (!directionLocked && !isVertical) return;
                        
                        let duration = Math.max(1, Date.now() - startTime)
                        let dy = cardTranslate.y
                        let velocity = Math.abs(dy - initialY) / duration

                        if (isVertical && dy < -100 && (velocity > 0.5 || dy < -200)) {
                            swipeAwayAnim.start()
                        } else {
                            snapBackAnim.start()
                        }
                        isVertical = false
                        directionLocked = false
                    }

                    onReleased: handleRelease()
                    onCanceled: handleRelease()
                    
                    onClicked: {
                        if (Math.abs(cardTranslate.y) < 20 && !drag.active) {
                            let addr = toplevel.lastIpcObject ? toplevel.lastIpcObject.address : toplevel.address;
                            if (addr) {
                                let safeAddr = root.sanitizeAddr(addr);
                                Hyprland.dispatch("hl.dsp.focus({ window = 'address:" + safeAddr + "' })")
                                closeTimer.restart()
                            }
                        }
                    }
                }
                
                Item {
                    id: card
                    // Use explicit positioning instead of anchors to allow drag.target to work
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                    width: targetWidth
                    height: targetHeight + 50 // Space for header above or below
                    
                    property string windowAddr: parent.windowAddr
                    
                    // Drag logic
                    Drag.active: cardMouse.dragEnabled || cardMouse.drag.active
                    Drag.source: card
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    Drag.keys: ["window-address"]
                    Drag.mimeData: { 
                        "text/plain": windowAddr,
                        "text": windowAddr,
                        "window-address": windowAddr
                    }
                    
                    Connections {
                        target: root
                        function onForceResetDrag() {
                            cardMouse.dragEnabled = false
                        }
                    }

                    Drag.onDragStarted: console.log("DRAG STARTED for window: " + windowAddr)
                    Drag.onDragFinished: (dropAction) => {
                        console.log("DRAG FINISHED with action: " + dropAction)
                        Qt.callLater(() => { cardMouse.dragEnabled = false; })
                    }

                    transform: Translate { id: cardTranslate }

                    Behavior on x { enabled: !cardMouse.pressed; NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    Behavior on y { enabled: !cardMouse.pressed; NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                    // Base Scale with Stagger & Interaction
                    scale: {
                        let baseScale = cardMouse.pressed ? 0.95 : (cardMouse.containsMouse ? 1.02 : 1.0)
                        let holdScale = cardMouse.dragEnabled ? 0.85 : 1.0
                        let liftScale = Math.max(0.7, 1.0 + (cardTranslate.y / 1000.0))
                        return baseScale * liftScale * holdScale
                    }
                    
                    opacity: {
                        let baseOpacity = 1.0
                        let liftOpacity = Math.max(0.0, 1.0 + (cardTranslate.y / 600.0))
                        return baseOpacity * liftOpacity
                    }
                    
                    Behavior on scale { 
                        enabled: !swipeAwayAnim.running
                        NumberAnimation { duration: 200; easing.type: Easing.OutBack } 
                    }
                    Behavior on opacity { 
                        enabled: !cardMouse.pressed && !swipeAwayAnim.running
                        NumberAnimation { duration: 250 } 
                    }

                    NumberAnimation {
                        id: snapBackAnim
                        target: cardTranslate
                        property: "y"
                        to: 0
                        duration: 300
                        easing.type: Easing.OutBack
                    }

                    SequentialAnimation {
                        id: swipeAwayAnim
                        ParallelAnimation {
                            NumberAnimation { target: cardTranslate; property: "y"; to: -800; duration: 250; easing.type: Easing.InCubic }
                            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 200 }
                        }
                        ScriptAction {
                            script: {
                                let addr = toplevel.lastIpcObject ? toplevel.lastIpcObject.address : toplevel.address;
                                if (addr) {
                                    let safeAddr = root.sanitizeAddr(addr);
                                    Hyprland.dispatch("hl.dsp.window.close({ window = 'address:" + safeAddr + "' })")
                                }
                            }
                        }
                    }

                    // Card Content
                    Item {
                        anchors.fill: parent
                        
                        // Transparent Header
                        RowLayout {
                            id: header
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 50
                            spacing: 12
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Image {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                sourceSize: Qt.size(32, 32)
                                fillMode: Image.PreserveAspectFit
                                source: appIcon
                                visible: status === Image.Ready
                            }

                            Text {
                                Layout.fillWidth: true
                                text: toplevel.title || "Window"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                                elide: Text.ElideRight
                                opacity: 0.9
                            }

                            Button {
                                id: closeBtn
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                flat: true
                                background: Rectangle {
                                    radius: 13
                                    color: closeBtn.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                }
                                contentItem: Image {
                                    anchors.centerIn: parent
                                    source: shellRoot.icon("window-close-symbolic")
                                    sourceSize: Qt.size(14, 14)
                                    opacity: closeBtn.hovered ? 1.0 : 0.6
                                }
                                onClicked: {
                                    let addr = toplevel.lastIpcObject ? toplevel.lastIpcObject.address : toplevel.address;
                                    if (addr) {
                                        let safeAddr = root.sanitizeAddr(addr);
                                        Hyprland.dispatch("hl.dsp.window.close({ window = 'address:" + safeAddr + "' })")
                                    }
                                }
                            }
                        }

                        // Window Preview
                        Item {
                            anchors.top: header.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            
                            Rectangle {
                                id: mask
                                anchors.fill: parent
                                radius: 18
                                visible: false
                            }

                            ScreencopyView {
                                id: preview
                                anchors.fill: parent
                                captureSource: toplevel.wayland
                                live: true
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: preview
                                maskSource: mask
                            }
                            
                            // Visual border for the preview
                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                border.width: 1
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 18
                                color: "#111"
                                visible: !preview.hasContent
                                Text {
                                    anchors.centerIn: parent
                                    text: "..."
                                    color: "#444"
                                }
                            }
                        }
                    }
            }
        }
    }

        // --- All Workspaces View ---
        GridView {
            id: workspaceGrid
            anchors.fill: parent
            anchors.topMargin: 120
            anchors.bottomMargin: 100
            visible: root.viewMode === 1
            
            cellWidth: 440
            cellHeight: (cellWidth - 40) / root.monitorRatio + 88
            
            layoutDirection: Qt.RightToLeft
            flow: GridView.FlowTopToBottom
            leftMargin: 40
            rightMargin: 40
            clip: false

            add: Transition {
                NumberAnimation { property: "scale"; from: 0; to: 1; duration: 400; easing.type: Easing.OutBack }
            }
            
            remove: Transition {
                NumberAnimation { property: "scale"; to: 0; duration: 200 }
            }

            displaced: Transition {
                NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
            }
            
            // Background tap to dismiss
            TapHandler {
                onTapped: shellRoot.switcherOpen = false
            }
            
            model: (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : []
            
            delegate: Item {
                id: workspaceCard
                    width: workspaceGrid.cellWidth
                    height: workspaceGrid.cellHeight
                    
                    property var workspace: modelData
                    
                    // Hover and Interaction effects matching window cards
                    scale: workspaceMouse.pressed ? 0.98 : (workspaceMouse.containsMouse ? 1.02 : 1.0)
                    opacity: workspaceMouse.pressed ? 0.9 : 1.0
                    
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Item {
                        anchors.centerIn: parent
                        width: parent.width - 40
                        height: parent.height - 40
                        
                        // Header (Matching window card header)
                        RowLayout {
                            id: wsHeader
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 40
                            spacing: 12
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Image {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                sourceSize: Qt.size(32, 32)
                                fillMode: Image.PreserveAspectFit
                                source: shellRoot.icon("view-app-grid-symbolic")
                                opacity: 0.8
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Workspace " + workspace.id
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                                opacity: 0.9
                            }

                            Text {
                                text: workspace.toplevels.values.length + " windows"
                                color: "white"
                                font.pixelSize: 12
                                opacity: 0.5
                            }
                        }

                        // Desktop Preview (Matching window preview style)
                        Item {
                            anchors.top: wsHeader.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 8
                            
                            Rectangle {
                                id: wsPreviewBg
                                anchors.fill: parent
                                radius: 18
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.color: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === workspace.id ? "white" : Qt.rgba(1, 1, 1, 0.15)
                                border.width: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === workspace.id ? 2 : 1
                                clip: true
                                
                                // Wallpaper background with rounded clipping
                                Rectangle {
                                    id: wsMask
                                    anchors.fill: parent
                                    radius: 18
                                    visible: false
                                }

                                Image {
                                    id: wallpaperImg
                                    anchors.fill: parent
                                    source: shellRoot.wallpaperPath ? "file://" + shellRoot.wallpaperPath : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: wallpaperImg
                                    maskSource: wsMask
                                    opacity: 0.6
                                    visible: wallpaperImg.status === Image.Ready
                                }

                                Item {
                                    id: desktopPreview
                                    anchors.fill: parent
                                    anchors.margins: 4

                                    property real monW: root.screenDimensions.width
                                    property real monH: root.screenDimensions.height
                                    property real scale: Math.min(width / monW, height / monH)

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: desktopPreview.monW * desktopPreview.scale
                                        height: desktopPreview.monH * desktopPreview.scale
                                        color: "transparent"

                                        Repeater {
                                            model: workspace.toplevels.values
                                            delegate: Item {
                                                property var ipc: modelData.lastIpcObject
                                                x: (ipc && ipc.at && ipc.at.length >= 2) ? ipc.at[0] * desktopPreview.scale : 0
                                                y: (ipc && ipc.at && ipc.at.length >= 2) ? ipc.at[1] * desktopPreview.scale : 0
                                                width: (ipc && ipc.size && ipc.size.length >= 2) ? ipc.size[0] * desktopPreview.scale : 100 * desktopPreview.scale
                                                height: (ipc && ipc.size && ipc.size.length >= 2) ? ipc.size[1] * desktopPreview.scale : 100 * desktopPreview.scale

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: 4 * desktopPreview.scale
                                                    color: Qt.rgba(1, 1, 1, 0.1)
                                                    border.color: Qt.rgba(1, 1, 1, 0.2)
                                                    border.width: 1
                                                    clip: true

                                                    ScreencopyView {
                                                        id: workspaceThumb
                                                        anchors.fill: parent
                                                        captureSource: modelData.wayland
                                                        live: true
                                                        visible: hasContent
                                                    }
                                                    
                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: parent.width * 0.6
                                                        height: parent.height * 0.6
                                                        source: {
                                                            let identifiers = [modelData.initialClass, modelData.appId].filter(x => !!x);
                                                            for (let id of identifiers) {
                                                                let entry = DesktopEntries.heuristicLookup(id);
                                                                if (entry && entry.icon) return (entry.icon.startsWith("/") ? "file://" + entry.icon : "image://icon/" + entry.icon);
                                                            }
                                                            return "";
                                                        }
                                                        fillMode: Image.PreserveAspectFit
                                                        visible: !workspaceThumb.hasContent
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: workspaceMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Hyprland.dispatch("hl.dsp.focus({ workspace = " + workspace.id + " })");
                            closeTimer.restart();
                        }
                    }
                }
        }
    }

    Timer {
        id: closeTimer
        interval: 50
        onTriggered: shellRoot.switcherOpen = false
    }
}
