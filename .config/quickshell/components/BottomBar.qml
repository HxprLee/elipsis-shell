import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

// Dock handle + content. Implemented as a bottom-anchored, horizontally
// centered PanelWindow on the Top layer (no exclusive zone, input masked
// to the visible dock). The Top layer keeps the dock above regular
// windows while letting Overlay-layer full-screen panels (QuickSettings,
// TaskManager, PowerMenu, AppDrawer) cover it. mainBar morphs between
// 140×8 (handle) and content+48 × 96 (dock/overlay) inside the fixed
// surface, so the dock never appears off-center while it animates.
PanelWindow {
    id: root
    visible: true
    color: "transparent"

    // Layered surface (Top), not a popup: Hyprland renders layer-shell
    // popups above ALL layers, so a popup dock would draw over
    // Overlay-level full-screen panels. Top layer sits below Overlay.
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: WlrLayershell.None

    // Bottom edge only — the layer-shell protocol centers the surface
    // horizontally on the unanchored axis.
    anchors {
        bottom: true
    }

    // The surface is fixed at the largest dock geometry. Keeping it stable
    // across state transitions means the dock never appears off-center
    // while mainBar morphs between handle and dock sizes.
    implicitWidth: dockContent.implicitWidth + 48
    implicitHeight: 112

    // Input mask: only the visible dock surface (mainBar) intercepts input.
    // The surface itself stays fixed at the maximum dock geometry for every
    // state, so without this mask its transparent area would swallow
    // clicks across the whole bottom band even when collapsed to the
    // 140×8 handle pill.
    mask: Region { item: mainBar }

    // swipeDelta is forwarded from BackgroundBar's edge-touch MouseArea.
    // BackgroundBar is a PanelWindow whose surface reaches the true screen
    // bottom edge, so it captures edge swipes that this window's masked
    // input cannot reach. BottomBar applies the delta to animate the dock
    // along with the finger at half-travel.
    property point swipeDelta: Qt.point(0, 0)
    property bool isSwiping: false

    // Proportional scale factor applied when swiping down on an open dock.
    // 1.0 = full size, 0.5 = half size. Set by onSwipeDeltaChanged during
    // swipe; reset to 1.0 by State PropertyActions when the dock collapses.
    property real shrinkFactor: 1.0

    property bool hasWindows: shellRoot.hasWindowsOnCurrentWs

    property bool _lockState: false
    property bool forceMinimized: false

    // barState lives on shellRoot so BackgroundBar.qml can react to it.
    // "handle" | "dock" | "overlay".
    property string barState: shellRoot.barState

    // Close any open context menu when the bar state changes (e.g. user
    // swipes down to overlay state from inside a right-click menu).
    Connections {
        target: shellRoot
        function onBarStateChanged() {
            if (root.screen) {
                shellRoot.closeContextMenu(root.screen);
            }
        }
    }

    Timer {
        id: autoHideTimer
        interval: 10000
        repeat: false
        onTriggered: {
            if (barState === "overlay") {
                root.setBarState(hasWindows ? "handle" : "dock", true);
            }
        }
    }

    function setBarState(newState, lock = false) {
        // Reset any in-flight swipe translate so the spring/snaps don't
        // fight the morphing animation.
        barTranslate.x = 0;
        barTranslate.y = 0;
        shrinkFactor = 1.0;
        isSwiping = false;

        // Exclusive zone is owned by BackgroundBar.qml (24px always). This
        // window floats above it and never reserves space.
        shellRoot.barState = newState;

        // Manage force minimized state
        if (newState === "handle" && !hasWindows && lock) {
            forceMinimized = true;
        } else if (newState !== "handle") {
            forceMinimized = false;
        }

        if (newState === "overlay")
            autoHideTimer.restart();
        else
            autoHideTimer.stop();

        if (lock) {
            _lockState = true;
            lockTimer.restart();
        }
    }

    Timer {
        id: lockTimer
        interval: 400
        onTriggered: {
            root._lockState = false;
            let syncState = (hasWindows || forceMinimized) ? "handle" : "dock";
            if (barState !== "overlay" && barState !== syncState)
                root.setBarState(syncState);
        }
    }

    // ── Hyprland tracking ──
    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            syncState();
        }
        function onFocusedWorkspaceChanged() {
            forceMinimized = false;
            syncState();
        }

        function syncState() {
            if (!root._lockState && barState !== "overlay") {
                let targetState = (root.hasWindows || root.forceMinimized) ? "handle" : "dock";
                if (barState !== targetState)
                    root.setBarState(targetState);
            }
        }
    }

    // React to hasWindows changes
    onHasWindowsChanged: {
        if (hasWindows)
            forceMinimized = false;

        if (!_lockState && barState !== "overlay") {
            let targetState = (hasWindows || forceMinimized) ? "handle" : "dock";
            if (barState !== targetState)
                root.setBarState(targetState);
        }
    }

    // Responds to swipeDelta forwarded from BackgroundBar's MouseArea (which
    // sits on the true screen-bottom surface and captures edge swipes).
    Connections {
        target: root
        function onSwipeDeltaChanged() {
            let dx = root.swipeDelta.x;
            let dy = root.swipeDelta.y;

            isSwiping = (Math.abs(dx) > 5 || Math.abs(dy) > 5);

            // Horizontal swipe feedback — only in handle state; dock/overlay
            // reserve horizontal for workspace switching (BackgroundBar).
            if (barState === "handle") {
                barTranslate.x = dx * 0.6;
            } else {
                barTranslate.x = 0;
            }
            barTranslate.y = dy * 0.5;

            // Scale the dock down proportionally to swipe depth (dy > 0 = swipe down).
            // Clamp to [0.5, 1.0]. The State's scale PropertyChanges won't fight
            // this because State changes don't touch mainBar.scale directly.
            if (barState !== "handle") {
                shrinkFactor = Math.max(0.5, Math.min(1.0, 1.0 - (dy / 400)));
            }
        }
    }

    function openMenu(item, app) {
        let pos = item.mapToItem(root.contentItem, 0, 0);
        let globalX = root.x + pos.x + item.width / 2;
        let globalY = root.y + pos.y - 12;

        let menuModel = [];

        // Pin/Unpin item
        menuModel.push({
            text: app.isPinned ? "Unpin app from dock" : "Pin app to dock",
            icon: shellRoot.icon(app.isPinned ? "window-close-symbolic" : "view-app-grid-symbolic"),
            action: () => shellRoot.togglePin(app.id)
        });

        // Close item
        if (app.isRunning) {
            menuModel.push({
                text: "Close window",
                icon: shellRoot.icon("window-close-symbolic"),
                isDestructive: true,
                action: () => shellRoot.killApp(app.id)
            });
        }

        if (root.screen) {
            shellRoot.openContextMenuAtCursor(root.screen, menuModel);
        }
    }

    // Invisible grab-area expander. The visible dock (mainBar) is only
    // 8 px tall in handle state, which is awkward to grab on touch.
    // The hitbox matches the dock's widest content width and extends from
    // the popup bottom (== screen bottom) up past mainBar, so swipes that
    // start on the very bottom edge of the screen — like a smartphone
    // home-indicator gesture — are captured immediately. Without anchoring
    // to parent.bottom, the bottom 12 px of the popup sit outside the
    // mask and the touch falls through to whatever's underneath.
    //
    Rectangle {
        id: mainBar
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        transformOrigin: Item.Center
        scale: shrinkFactor

        transform: Translate {
            id: barTranslate
            x: 0
            y: 0

            // Horizontal swipe feedback uses a spring so the dock can
            // overshoot and settle (matches the workspace-switch gesture).
            // Disabled during active swipes so the explicit dx assignment
            // isn't fighting the spring.
            Behavior on x {
                enabled: !isSwiping
                SpringAnimation {
                    spring: 3
                    damping: 0.4
                    epsilon: 0.5
                }
            }

            // Vertical swipe snaps back when the swipe ends (swipeDelta → 0).
            // Disabled during swipes so the explicit dy tracking isn't overridden.
            Behavior on y {
                enabled: !isSwiping
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutQuart
                }
            }
        }

        // Apply dynamic material texture
        MaterialSurface {
            anchors.fill: parent
            radius: parent.radius
            visible: root.barState !== "handle"
        }

        state: barState

        states: [
            State {
                name: "handle"
                PropertyChanges {
                    target: mainBar
                    width: 140
                    height: 8
                    radius: 4
                    anchors.bottomMargin: 4
                    color: "white"
                }
                PropertyChanges {
                    target: dockContent
                    opacity: 0
                    scale: 0.8
                    visible: false
                }
            },
            State {
                name: "dock"
                PropertyChanges {
                    target: mainBar
                    width: (root.hasWindows || root.forceMinimized) ? 140 : (dockContent.implicitWidth + 48)
                    height: 96
                    radius: 48
                    anchors.bottomMargin: 8
                    color: "transparent"
                }
                PropertyChanges {
                    target: dockContent
                    opacity: 1
                    scale: 1
                    visible: true
                }
            },
            State {
                name: "overlay"
                PropertyChanges {
                    target: mainBar
                    width: dockContent.implicitWidth + 48
                    height: 96
                    radius: 48
                    anchors.bottomMargin: 8
                    color: "transparent"
                }
                PropertyChanges {
                    target: dockContent
                    opacity: 1
                    scale: 1
                    visible: true
                }
            }
        ]

        transitions: [
            Transition {
                from: "*"
                to: "*"
                NumberAnimation {
                    properties: "width,height,radius,opacity,scale"
                    duration: 500
                    easing.type: Easing.OutExpo
                }
                ColorAnimation {
                    duration: 500
                }
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
                width: 64
                height: 64
                flat: true
                background: Item {}
                contentItem: Item {
                    scale: menuBtn.pressed ? 0.9 : (menuBtn.hovered ? 1.15 : 1.0)
                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutBack
                        }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: 50
                        height: 50
                        sourceSize: Qt.size(64, 64)
                        source: shellRoot.icon("view-app-grid-symbolic")
                    }
                }
                onClicked: {
                    if (shellRoot.appDrawerOpen) {
                        shellRoot.appDrawerOpen = false;
                    } else {
                        shellRoot.closeOtherOverlays("drawer");
                        shellRoot.appDrawerOpen = !shellRoot.appDrawerOpen;
                    }
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
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                add: Transition {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: 150
                        }
                        ParallelAnimation {
                            NumberAnimation {
                                property: "scale"
                                from: 0
                                to: 1.0
                                duration: 400
                                easing.type: Easing.OutBack
                            }
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1.0
                                duration: 400
                            }
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "scale"
                            to: 0
                            duration: 300
                            easing.type: Easing.InBack
                        }
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: 300
                        }
                    }
                }

                addDisplaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                removeDisplaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                move: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                moveDisplaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }

                delegate: Item {
                    id: delegateRoot
                    width: 64
                    height: 64
                    property int windowCount: model.windowCount || 0
                    property bool isFocused: model.isFocused || false
                    z: dragHandler.dragging ? 100 : 0

                    DropArea {
                        anchors.fill: parent
                        keys: ["dock-app"]
                        onEntered: drag => {
                            if (drag.source.dragAppId !== model.id) {
                                shellRoot.movePinnedApp(drag.source.dragAppId, model.id);
                            }
                        }
                    }

                    Button {
                        id: dockButton
                        width: 64
                        height: 64
                        flat: true
                        background: Item {}

                        // Drag positioning logic
                        property real dragTargetGlobalX: 0

                        x: dragHandler.dragging ? dragTargetGlobalX - delegateRoot.x : 0
                        y: 0

                        NumberAnimation {
                            id: snapX
                            target: dockButton
                            property: "x"
                            to: 0
                            duration: 300
                            easing.type: Easing.OutBack
                        }

                        // Drag identity
                        property string dragAppId: model.id
                        Drag.active: dragHandler.dragging
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
                            scale: dragHandler.dragging ? 1.2 : (dragHandler.didLongPress ? 1.2 : (dockButton.pressed ? 0.9 : (dragHandler.containsMouse && !snapX.running ? 1.15 : 1.0)))
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                }
                            }
                            opacity: dragHandler.dragging ? 0.8 : 1.0

                            Image {
                                id: appIcon
                                anchors.centerIn: parent
                                width: 48
                                height: 48
                                fillMode: Image.PreserveAspectFit
                                source: {
                                    if (!model.icon)
                                        return "";
                                    if (model.icon.startsWith("/"))
                                        return "file://" + model.icon;
                                    return "image://icon/" + model.icon;
                                }
                                visible: false // Hidden so DropShadow can render it without duplicating
                            }

                            DropShadow {
                                anchors.fill: appIcon
                                source: appIcon
                                color: Qt.rgba(0, 0, 0, 0.2)
                                radius: 12
                                samples: 18
                                verticalOffset: 0
                                transparentBorder: true
                                visible: appIcon.status === Image.Ready
                            }

                            // Running indicator dots (one per instance, max 5)
                            Row {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -4
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3
                                visible: model.isRunning

                                Repeater {
                                    model: Math.min(delegateRoot.windowCount, 5)

                                    Rectangle {
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: delegateRoot.isFocused ? Qt.rgba(0.2, 0.5, 1.0, 1.0) : "white"
                                        opacity: 0.9
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 200
                                            }
                                        }
                                    }
                                }
                            }

                
                        }

                        onClicked: {
                            console.log("Dock button clicked: " + model.name);
                            if (root.screen) {
                                shellRoot.closeContextMenu(root.screen);
                            }
                            if (model.isRunning && model.address) {
                                let safeAddr = model.address.replace(/[^0-9a-fA-Fx]/g, "");
                                Hyprland.dispatch("hl.dsp.focus({ window = 'address:" + safeAddr + "' })");
                            } else if (model.entry) {
                                model.entry.execute();
                            } else if (model.exec) {
                                launchProcess.command = ["sh", "-c", model.exec];
                                launchProcess.running = true;
                            }
                        }

                        // Unified input handler: tap, right-click, long-press, drag
                        MouseArea {
                            id: dragHandler
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            pressAndHoldInterval: 300
                            hoverEnabled: true

                            property bool dragging: false
                            property real startMouseX: 0
                            property real startMouseY: 0
                            property real startItemGlobalX: 0
                            property bool didLongPress: false
                            property bool didSwipe: false

                            onPressed: mouse => {
                                snapX.stop();
                                let p = mapToItem(dockListView.contentItem, mouse.x, mouse.y);
                                startMouseX = p.x;
                                startMouseY = p.y;

                                startItemGlobalX = delegateRoot.x + dockButton.x;
                                didLongPress = false;
                                didSwipe = false;
                            }

                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.openMenu(dockButton, model);
                                } else if (!didLongPress && !dragging && !didSwipe) {
                                    dockButton.clicked();
                                }
                            }

                            onPressAndHold: {
                                if (dragging || didSwipe)
                                    return;
                                didLongPress = true;
                            }

                            onPositionChanged: mouse => {
                                let p = mapToItem(dockListView.contentItem, mouse.x, mouse.y);

                                let dx = p.x - startMouseX;
                                let dy = p.y - startMouseY;

                                if (!didSwipe && (Math.abs(dx) > 15 || Math.abs(dy) > 15)) {
                                    didSwipe = true;
                                }

                                if (!dragging && didLongPress && (mouse.buttons & Qt.LeftButton)) {
                                    if (didSwipe) {
                                        if (root.screen) {
                                            shellRoot.closeContextMenu(root.screen);
                                        }

                                        let rawX = startItemGlobalX + (p.x - startMouseX);
                                        let maxX = Math.max(0, dockListView.width - dockButton.width);
                                        dockButton.dragTargetGlobalX = Math.max(0, Math.min(maxX, rawX));

                                        dragging = true;

                                        if (root.barState === "overlay") {
                                            autoHideTimer.stop();
                                        }
                                    }
                                }

                                if (dragging) {
                                    let rawX = startItemGlobalX + (p.x - startMouseX);
                                    let maxX = Math.max(0, dockListView.width - dockButton.width);
                                    dockButton.dragTargetGlobalX = Math.max(0, Math.min(maxX, rawX));
                                }
                            }

                            onReleased: {
                                if (dragging) {
                                    dockButton.Drag.drop();
                                    let curX = dockButton.x;
                                    dragging = false;
                                    snapX.from = curX;
                                    snapX.start();

                                    if (root.barState === "overlay") {
                                        autoHideTimer.restart();
                                    }
                                } else if (didLongPress) {
                                    root.openMenu(dockButton, model);
                                }
                                didLongPress = false;
                            }

                            onCanceled: {
                                if (dragging) {
                                    let curX = dockButton.x;
                                    dragging = false;
                                    snapX.from = curX;
                                    snapX.start();

                                    if (root.barState === "overlay") {
                                        autoHideTimer.restart();
                                    }
                                }
                                didLongPress = false;
                            }
                        }

                        ToolTip.visible: dragHandler.containsMouse && !dragHandler.dragging
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
            id: collapseArea
            // Covers the MaterialSurface and empty dock space. Dock buttons
            // (icon + menu) have their own MouseAreas with onClicked handlers
            // that don't call setBarState, so they take priority here.
            // Collapse only fires on tap — if isSwiping is true or the finger
            // moved significantly, it's a swipe, not a tap.
            anchors.fill: parent
            enabled: barState !== "handle"
            property real pressX: 0
            property real pressY: 0

            onPressed: mouse => {
                pressX = mouse.x;
                pressY = mouse.y;
            }

            onClicked: mouse => {
                let dx = mouse.x - pressX;
                let dy = mouse.y - pressY;
                // Ignore if the pointer moved more than 15px — it's a swipe.
                if (Math.abs(dx) <= 15 && Math.abs(dy) <= 15 && !isSwiping)
                    root.setBarState("handle", true);
            }
            z: -1
        }
    }
}
