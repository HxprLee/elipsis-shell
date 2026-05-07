import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls

PanelWindow {
    id: root
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 24   // 8px top + 8px bar + 8px bottom

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: implicitHeight
    aboveWindows: true

    property bool hasWindows: shellRoot.hasWindowsOnCurrentWs
    property real swipeStartTime: 0
    property string barState: "handle"
    property bool _lockState: false
    property bool forceMinimized: false
    property bool _switcherTriggered: false

    onBarStateChanged: if (globalMenu.opened) globalMenu.close()

    Timer {
        id: switcherHoldTimer
        interval: 80
        onTriggered: {
            if (touchArea.pressed && internal.isSwipe) {
                shellRoot.switcherOpen = true
                _switcherTriggered = true
            }
        }
    }

    Timer {
        id: autoHideTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (barState === "overlay") {
                root.setBarState(hasWindows ? "handle" : "dock", true)
            }
        }
    }

    function setBarState(newState, lock = false) {
        barState = newState

        // Manage force minimized state
        if (newState === "handle" && !hasWindows && lock) {
            forceMinimized = true
        } else if (newState !== "handle") {
            forceMinimized = false
        }

        // Update window geometry
        switch (newState) {
        case "handle":
            root.implicitHeight = 24
            root.exclusiveZone = 24
            break
        case "dock":
            root.implicitHeight = 112
            root.exclusiveZone = 112
            break
        case "overlay":
            root.implicitHeight = 112
            root.exclusiveZone = 0
            break
        }

        if (newState === "overlay") autoHideTimer.restart()
        else autoHideTimer.stop()

        if (lock) {
            _lockState = true
            lockTimer.restart()
        }
    }

    Timer {
        id: lockTimer
        interval: 400
        onTriggered: {
            root._lockState = false
            let syncState = (hasWindows || forceMinimized) ? "handle" : "dock"
            if (barState !== "overlay" && barState !== syncState) root.setBarState(syncState)
        }
    }

    // ── Hyprland tracking ──
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() { syncState() }
        function onFocusedWorkspaceChanged() { 
            forceMinimized = false
            syncState()
        }

        function syncState() {
            if (!root._lockState && barState !== "overlay") {
                let targetState = (root.hasWindows || root.forceMinimized) ? "handle" : "dock"
                if (barState !== targetState) root.setBarState(targetState)
            }
        }
    }

    // React to hasWindows changes
    onHasWindowsChanged: {
        if (hasWindows) forceMinimized = false

        if (!_lockState && barState !== "overlay") {
            let targetState = (hasWindows || forceMinimized) ? "handle" : "dock"
            if (barState !== targetState) root.setBarState(targetState)
        }
    }

    QtObject {
        id: internal
        property bool isSwipe: false
    }

    MultiPointTouchArea {
        id: touchArea
        anchors.fill: parent
        property real startX: 0
        property real startY: 0
        property bool pressed: false

        onPressed: (touchPoints) => {
            if (touchPoints.length > 0) {
                startX = touchPoints[0].x
                startY = touchPoints[0].y
                swipeStartTime = Date.now()
                internal.isSwipe = false
            }
        }

        onUpdated: (touchPoints) => {
            if (touchPoints.length > 0) {
                let point = touchPoints[0]
                let dx = point.x - startX
                let dy = point.y - startY

                if (!internal.isSwipe && (Math.abs(dx) > 15 || Math.abs(dy) > 15)) {
                    internal.isSwipe = true
                    pressed = true
                }

                if (internal.isSwipe) {
                    if (barState === "handle") barTranslate.x = dx * 0.6
                    else barTranslate.x = 0

                    if (barState !== "handle" && dy > 40 && !root._lockState) {
                        root.setBarState("handle", true)
                    }

                    if (dy < -100 && !switcherHoldTimer.running && !_switcherTriggered) {
                        switcherHoldTimer.start()
                    } else if (dy > -60) {
                        switcherHoldTimer.stop()
                    }
                }
            }
        }

        onReleased: (touchPoints) => {
            pressed = false
            barTranslate.x = 0
            if (touchPoints.length > 0) {
                let point = touchPoints[0]
                let dx = point.x - startX
                let dy = point.y - startY
                let duration = Date.now() - swipeStartTime
                let velocity = Math.abs(dy) / Math.max(1, duration)

                if (internal.isSwipe) {
                    // Horizontal swipe → switch workspace
                    if (Math.abs(dx) > 100) {
                        Hyprland.dispatch("workspace " + (dx < 0 ? "+1" : "-1"))
                    }

                    if (dy < -30 && !_switcherTriggered) {
                        if (velocity > 0.8) {
                            Hyprland.dispatch("killactive")
                            root.setBarState("handle", true)
                        } else if (barState !== "overlay") {
                            root.setBarState("overlay")
                        }
                    }
                }
            }
            internal.isSwipe = false
            switcherHoldTimer.stop()
            _switcherTriggered = false
        }
    }

    function openMenu(item, app) {
        let pos = item.mapToItem(root.contentItem, 0, 0)
        
        let menuModel = []
        
        // Pin/Unpin item
        menuModel.push({
            text: app.isPinned ? "Unpin app from dock" : "Pin app to dock",
            icon: shellRoot.icon(app.isPinned ? "window-close-symbolic" : "view-app-grid-symbolic"), // Placeholders
            action: () => shellRoot.togglePin(app.id)
        })
        
        // Close item
        if (app.isRunning) {
            menuModel.push({
                text: "Close window",
                icon: shellRoot.icon("window-close-symbolic"),
                isDestructive: true,
                action: () => shellRoot.killApp(app.id)
            })
        }
        
        globalMenu.model = menuModel
        
        globalMenu.x = pos.x + (item.width - 200) / 2
        globalMenu.y = pos.y - globalMenu.height - 12
        globalMenu.open()
    }

    AppContextMenu {
        id: globalMenu
    }

    Rectangle {
        id: mainBar
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        // clip: true -- removed to avoid clipping shadow if added later, but Popup solves main issue

        transform: Translate {            id: barTranslate
            x: 0
            Behavior on x {
                enabled: !touchArea.pressed
                SpringAnimation { spring: 3; damping: 0.4; epsilon: 0.5 }
            }
        }


        state: barState

        states: [
            State {
                name: "handle"
                PropertyChanges { target: mainBar; width: 140; height: 8; radius: 4; anchors.bottomMargin: 8; color: "white" }
                PropertyChanges { target: dockContent; opacity: 0; scale: 0.8; visible: false }
            },
            State {
                name: "dock"
                PropertyChanges { target: mainBar; width: (root.hasWindows || root.forceMinimized) ? 140 : (dockContent.implicitWidth + 48); height: 96; radius: 48; anchors.bottomMargin: 12; color: Qt.rgba(0.05, 0.05, 0.1, 0.95) }
                PropertyChanges { target: dockContent; opacity: 1; scale: 1; visible: true }
            },
            State {
                name: "overlay"
                PropertyChanges { target: mainBar; width: dockContent.implicitWidth + 48; height: 96; radius: 48; anchors.bottomMargin: 12; color: Qt.rgba(0.05, 0.05, 0.1, 0.95) }
                PropertyChanges { target: dockContent; opacity: 1; scale: 1; visible: true }
            }
        ]

        transitions: [
            Transition {
                from: "*"; to: "*"
                NumberAnimation {
                    properties: "width,height,radius,anchors.bottomMargin,opacity,scale";
                    duration: 500;
                    easing.type: Easing.OutExpo
                }
                ColorAnimation { duration: 500 }
            }
        ]

        Row {
            id: dockContent
            anchors.centerIn: parent
            spacing: 24
            opacity: 0
            scale: 0.8

            // Elipsis Menu Toggle
            Button {
                id: menuBtn
                width: 64; height: 64
                flat: true
                background: Item { }
                contentItem: Item {
                    scale: menuBtn.pressed ? 0.9 : (menuBtn.hovered ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Image {
                        anchors.centerIn: parent
                        width: 50; height: 50
                        sourceSize: Qt.size(64, 64)
                        source: shellRoot.icon("view-app-grid-symbolic")
                    }
                }
                onClicked: {
                    shellRoot.appDrawerOpen = !shellRoot.appDrawerOpen
                }
                ToolTip.visible: hovered
                ToolTip.text: "Menu"
                ToolTip.delay: 500
            }

            ListView {
                id: dockListView
                width: contentWidth
                height: 64
                orientation: ListView.Horizontal
                spacing: 24
                model: shellRoot.dockAppsModel
                interactive: false

                Behavior on width {
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }

                add: Transition {
                    SequentialAnimation {
                        PauseAnimation { duration: 150 }
                        ParallelAnimation {
                            NumberAnimation { property: "scale"; from: 0; to: 1.0; duration: 400; easing.type: Easing.OutBack }
                            NumberAnimation { property: "opacity"; from: 0; to: 1.0; duration: 400 }
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "scale"; to: 0; duration: 300; easing.type: Easing.InBack }
                        NumberAnimation { property: "opacity"; to: 0; duration: 300 }
                    }
                }

                addDisplaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
                }

                removeDisplaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
                }

                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 400; easing.type: Easing.OutCubic }
                }

                delegate: Item {
                    width: 64; height: 64
                    
                    DropArea {
                        anchors.fill: parent
                        keys: ["dock-app"]
                        onEntered: (drag) => {
                            if (drag.source.appId !== model.id) {
                                shellRoot.movePinnedApp(drag.source.appId, model.id)
                            }
                        }
                    }

                    Button {
                        id: dockButton
                        width: 64; height: 64
                        flat: true
                        background: Item { }
                        
                        // Manual positioning for drag
                        x: dragArea.dragActive ? dragArea.targetX - dragArea.dragStartX : 0
                        y: 0 // Restrict vertical movement to the row
                        z: dragArea.dragActive ? 100 : 0

                        // Drag & Drop
                        property string appId: model.id
                        Drag.active: dragArea.dragActive
                        Drag.source: dockButton
                        Drag.keys: ["dock-app"]
                        Drag.hotSpot.x: 32
                        Drag.hotSpot.y: 32

                        icon.width: 48
                        icon.height: 48
                        icon.color: "transparent"
                        icon.name: model.icon.startsWith("/") ? "" : model.icon
                        icon.source: model.icon.startsWith("/") ? "file://" + model.icon : ""

                        contentItem: Item {
                            scale: dockButton.pressed ? 0.9 : (dockButton.hovered ? 1.15 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                            opacity: (dockButton.pressed || dragArea.drag.active) ? 0.7 : 1.0

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 48; height: 48
                                fillMode: Image.PreserveAspectFit
                                source: {
                                    if (!model.icon) return "";
                                    if (model.icon.startsWith("/")) return "file://" + model.icon;
                                    return "image://icon/" + model.icon;
                                }
                                visible: status === Image.Ready
                            }

                            // Running indicator dot
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -4
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 4; height: 4; radius: 2
                                color: "white"
                                visible: opacity > 0
                                opacity: model.isRunning ? 0.8 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                scale: model.isRunning ? 1.0 : 0.0
                                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                font.pixelSize: 36
                                color: "white"
                                enabled: false
                                text: {
                                    let iconName = model.icon.toLowerCase()
                                    let appName = model.name.toLowerCase()
                                    if (iconName.includes("firefox") || appName.includes("firefox") || iconName.includes("browser")) return "🌐"
                                    if (iconName.includes("folder") || appName.includes("files") || iconName.includes("nautilus")) return "📂"
                                    if (iconName.includes("terminal") || appName.includes("terminal")) return "📟"
                                    if (iconName.includes("code") || appName.includes("code")) return "📝"
                                    if (iconName.includes("settings")) return "⚙️"
                                    return model.name.charAt(0).toUpperCase()
                                }
                            }
                        }

                        onClicked: {
                            console.log("Dock button clicked: " + model.name)
                            if (globalMenu.opened) {
                                globalMenu.close()
                                return
                            }
                            if (model.isRunning && model.address) {
                                Hyprland.dispatch("focuswindow address:" + model.address)
                            } else if (model.entry) {
                                model.entry.execute()
                            } else {
                                launchProcess.command = ["sh", "-c", model.exec + " &"]
                                launchProcess.running = true
                            }
                        }

                        // Handle right click and drag
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            pressAndHoldInterval: 300
                            
                            property bool dragActive: false
                            property real dragStartX: 0
                            property real dragStartY: 0
                            property real targetX: 0
                            property real targetY: 0
                            property bool longPressed: false
                            
                            onPressed: (mouse) => {
                                dragStartX = mouse.x
                                dragStartY = mouse.y
                                longPressed = false
                            }

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    console.log("Dock button right-clicked: " + model.name)
                                    root.openMenu(dockButton, model)
                                } else if (!longPressed && !dragActive) {
                                    dockButton.clicked()
                                }
                            }

                            onPressAndHold: (mouse) => {
                                if (dragActive) return;
                                longPressed = true
                                console.log("Dock button long-pressed: " + model.name)
                                root.openMenu(dockButton, model)
                            }
                            
                            onPositionChanged: (mouse) => {
                                if (!dragActive && (mouse.buttons & Qt.LeftButton)) {
                                    let dx = mouse.x - dragStartX
                                    let dy = mouse.y - dragStartY
                                    if (Math.abs(dx) > 20 || Math.abs(dy) > 20) {
                                        if (globalMenu.opened) globalMenu.close()
                                        
                                        let p = mapToItem(dockButton.parent, mouse.x, mouse.y)
                                        targetX = p.x
                                        targetY = p.y
                                        dragActive = true
                                        console.log("Drag started via movement: " + model.name)
                                    }
                                }

                                if (dragActive) {
                                    let p = mapToItem(dockButton.parent, mouse.x, mouse.y)
                                    targetX = p.x
                                    targetY = p.y
                                }
                            }

                            onReleased: {
                                if (dragActive) {
                                    console.log("Dock button dropped: " + model.name)
                                    dragActive = false
                                    dockButton.Drag.drop()
                                }
                            }

                            onCanceled: {
                                dragActive = false
                            }
                        }

                        ToolTip.visible: hovered && !globalMenu.opened && !dragArea.drag.active
                    ToolTip.text: model.name
                    ToolTip.delay: 500
                }
            }
        }
    } // End of mainBar

    // Shared process for launching apps
    Process {
        id: launchProcess
        running: false
    }

    MouseArea {
        anchors.fill: parent
        enabled: barState !== "handle"
        onClicked: root.setBarState("handle", true)
        z: -1
    }
}
}
