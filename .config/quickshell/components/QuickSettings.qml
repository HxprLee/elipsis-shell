import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import "../services"
import "quicksettings"

PanelWindow {
    id: qs
    visible: false
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.layer: WlrLayershell.Overlay

    WlrLayershell.keyboardFocus: isOpen ? WlrLayershell.OnDemand : WlrLayershell.None

    property bool isOpen: UIState.panelOpen
    property real dragOffset: UIState.panelDragOffset
    property real smoothMorphProgress: 0
    property bool morphComplete: false
    onSmoothMorphProgressChanged: {
        if (isOpen && smoothMorphProgress >= 1.0) {
            morphComplete = true;
        }
    }
    Behavior on smoothMorphProgress {
        id: morphSpringBehavior
        enabled: false
        SpringAnimation { spring: 3; damping: 0.6; mass: 1.0 }
    }
    property real progress: {
        if (!isOpen && dragOffset > 0)
            return Math.min(1.0, dragOffset / 60.0);
        if (isOpen && dragOffset < 0)
            return Math.max(0.0, 1.0 - (Math.abs(dragOffset) / 60.0));
        return isOpen ? 1.0 : 0.0;
    }

    // ── Pipewire audio ──
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    property var audioNode: Pipewire.defaultAudioSink?.audio ?? null

    // ── Connectivity ──
    property bool wifiEnabled: Network.wifiEnabled
    property bool bluetoothEnabled: Bluetooth.bluetoothEnabled

    property int batteryPct: -1
    property string batteryStatus: ""

    function toggleWifi() {
        Network.toggleWifi();
    }
    function toggleBluetooth() {
        Bluetooth.toggleBluetooth();
    }

    // ── Brightness ──
    // All backlight / kbd-backlight / dark-mode logic now lives in
    // services/Brightness.qml. Consumers reference Brightness.brightnessValue,
    // Brightness.maxBrightness, Brightness.kbdBacklightValue, etc.

    // ── Drag / open animation ──
    onDragOffsetChanged: {
        let rawProgress = 0.0;
        if (!isOpen && dragOffset > 0) {
            // Dragging down while closed
            rawProgress = Math.min(1.0, dragOffset / 60.0);
            panelBehavior.enabled = false;
            scaleBehavior.enabled = false;
            opacityBehavior.enabled = false;
            bgOpacityBehavior.enabled = false;
            morphSpringBehavior.enabled = false;
            smoothMorphProgress = rawProgress;
        } else if (isOpen && dragOffset < 0) {
            // Dragging up while open
            rawProgress = Math.max(0.0, 1.0 - (Math.abs(dragOffset) / 60.0));
            panelBehavior.enabled = false;
            scaleBehavior.enabled = false;
            opacityBehavior.enabled = false;
            bgOpacityBehavior.enabled = false;
            morphSpringBehavior.enabled = false;
            smoothMorphProgress = rawProgress;
        } else if (dragOffset === 0) {
            panelBehavior.enabled = true;
            scaleBehavior.enabled = true;
            opacityBehavior.enabled = true;
            bgOpacityBehavior.enabled = true;
            morphSpringBehavior.enabled = true;
            rawProgress = isOpen ? 1.0 : 0.0;
            smoothMorphProgress = rawProgress;
        }

        // Calculate physics values
        panelContainer.y = 10 + (rawProgress * 40);
        panelContainer.bloomScale = 0.85 + (rawProgress * 0.15);
        panelContainer.opacity = rawProgress > 0 ? 1.0 : 0.0; // Instant opacity for morphing elements
        bgDim.opacity = rawProgress;
    }

    onIsOpenChanged: {
        if (isOpen) {
            morphComplete = true;
        } else {
            morphComplete = false;
        }
        panelBehavior.enabled = true;
        scaleBehavior.enabled = true;
        opacityBehavior.enabled = true;
        bgOpacityBehavior.enabled = true;
        morphSpringBehavior.enabled = true;
        smoothMorphProgress = isOpen ? 1.0 : 0.0;
        if (isOpen) {
            qs.visible = true;
            panelContainer.y = 50;
            panelContainer.bloomScale = 1.0;
            panelContainer.opacity = 1.0;
            bgDim.opacity = 1.0;
        } else {
            if (expandedOverlay.isExpanded)
                controlPanel.closeExpandedView();
            // Reset edit mode on close so the next open starts clean —
            // otherwise the next open shows minus-bar drag handles on
            // every toggle, and a tap inside an empty cell drags
            // instead of activating. saveLayout() persists any pending
            // changes (so the user doesn't lose work) before clearing.
            if (controlPanel.editMode) {
                controlPanel.saveLayout();
                controlPanel.editMode = false;
            }
            if (addControlPopup.opacity > 0) {
                addControlPopup.close();
            }
            panelContainer.y = 10;
            panelContainer.bloomScale = 0.85;
            panelContainer.opacity = 0.0;
            bgDim.opacity = 0.0;
        }
    }

    // ── Background dim ──
    Item {
        id: bgDim
        anchors.fill: parent
        opacity: 0

        Image {
            id: bgBlur
            anchors.fill: parent
            source: Wallpapers.blurredWallpaperPath
            cache: true
            fillMode: Image.PreserveAspectCrop

            Connections {
                target: Wallpapers
                function onBlurVersionChanged() {
                    let s = bgBlur.source;
                    bgBlur.source = "";
                    bgBlur.source = s;
                }
            }
            visible: Wallpapers.usePrecomputedBlur && Wallpapers.staticBlurEnabled
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.3)
        }

        Behavior on opacity {
            id: bgOpacityBehavior
            SpringAnimation { spring: 3; damping: 0.6; mass: 1.0 }
        }

        MouseArea {
            id: outerArea
            anchors.fill: parent
            enabled: isOpen
            property real startY: 0
            property bool isDragging: false

            onPressed: mouse => {
                startY = mapToItem(null, mouse.x, mouse.y).y;
                isDragging = false;
            }
            onPositionChanged: mouse => {
                if (isOpen) {
                    let mappedY = mapToItem(null, mouse.x, mouse.y).y;
                    let dy = mappedY - startY;
                    if (dy < -10) {
                        isDragging = true;
                        UIState.panelDragOffset = dy;
                    }
                }
            }
            onReleased: mouse => {
                if (isDragging) {
                    if (UIState.panelDragOffset < -60) {
                        UIState.panelOpen = false;
                    }
                    UIState.panelDragOffset = 0;
                    isDragging = false;
                } else {
                    // Click in the bgDim strip (outside controlPanel /
                    // notifPanel). The inner expandedOverlay MouseArea
                    // already handles all clicks inside controlPanel bounds,
                    // so this branch only fires for clicks in the bgDim
                    // region — geographically far from any toggle, so
                    // there's no risk of opening another toggle's expanded
                    // view here. Close the panel (or the expanded view if
                    // one is active).
                    //
                    // Exception: while the Add-a-Control popup is open, an
                    // outside tap dismisses just the popup and leaves the
                    // control center open. Without this, tapping the dead
                    // zone beside the popup tore down the whole panel.
                    if (addControlPopup.opacity > 0) {
                        addControlPopup.close();
                    } else if (expandedOverlay.isExpanded) {
                        controlPanel.closeExpandedView();
                    } else {
                        UIState.panelOpen = false;
                    }
                }
            }
        }
    }

    // ── Panel container (two panels side by side) ──
    Item {
        id: panelContainer
        width: parent.width
        height: Math.max(controlPanel.height, notifPanel.height)
        y: 10
        property real bloomScale: 0.85
        opacity: 0.0

        Behavior on y {
            id: panelBehavior
            SpringAnimation { spring: 2.5; damping: 0.65; mass: 1.0 }
        }
        Behavior on bloomScale {
            id: scaleBehavior
            SpringAnimation { spring: 3; damping: 0.5; mass: 1.0 }
        }
        Behavior on opacity {
            id: opacityBehavior
            SpringAnimation { spring: 3; damping: 0.6; mass: 1.0 }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            enabled: isOpen
            property real startY: 0
            property bool isDragging: false

            onPressed: mouse => {
                startY = mapToItem(null, mouse.x, mouse.y).y;
                isDragging = false;
            }
            onPositionChanged: mouse => {
                if (isOpen) {
                    let mappedY = mapToItem(null, mouse.x, mouse.y).y;
                    let dy = mappedY - startY;
                    if (dy < -10) {
                        isDragging = true;
                        UIState.panelDragOffset = dy;
                    }
                }
            }
            onReleased: mouse => {
                if (isDragging) {
                    if (UIState.panelDragOffset < -60) {
                        UIState.panelOpen = false;
                    }
                    UIState.panelDragOffset = 0;
                    isDragging = false;
                }
            }
        }

        // ============================================
        // LEFT: NOTIFICATION CENTER (original design)
        // ============================================
        Rectangle {
            id: notifPanel
            anchors.left: parent.left
            anchors.leftMargin: 24
            width: 440
            height: 830
            radius: 28
            color: "transparent"
            transformOrigin: Item.TopLeft
            scale: panelContainer.bloomScale

            // ── Clock ──
            property string timeString: Qt.formatTime(new Date(), "HH:mm")
            property string dateString: Qt.formatDate(new Date(), "dddd, MMMM d")
            Timer {
                interval: 1000
                running: qs.isOpen || qs.dragOffset > 0
                repeat: true
                onTriggered: {
                    notifPanel.timeString = Qt.formatTime(new Date(), "HH:mm");
                    notifPanel.dateString = Qt.formatDate(new Date(), "dddd, MMMM d");
                }
            }

            Row {
                id: clockArea
                // Morph from StatusBar clock position to notification panel clock position
                // Uses screen-space coordinates divided by bloomScale to account for notifPanel's scale transform

                property real screenStartX: 16
                property real screenTargetX: 48
                property real screenStartY: 12
                property real screenTargetY: 74

                x: (screenStartX + (screenTargetX - screenStartX) * smoothMorphProgress) / panelContainer.bloomScale - 24
                y: (screenStartY + (screenTargetY - screenStartY) * smoothMorphProgress) / panelContainer.bloomScale - panelContainer.y

                spacing: 16

                Text {
                    id: timeText
                    text: notifPanel.timeString
                    color: "white"
                    font.pixelSize: (15 + (56 - 15) * smoothMorphProgress) / panelContainer.bloomScale
                    font.bold: true
                }
                Text {
                    text: notifPanel.dateString
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 18
                    opacity: smoothMorphProgress
                    anchors.baseline: timeText.baseline
                }
            }

            // Header
            RowLayout {
                id: notifHeader
                opacity: progress // Non-morphing content fades in
                anchors.top: clockArea.bottom
                anchors.topMargin: 24
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24
                anchors.rightMargin: 24

                Text {
                    text: "Notifications"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.fillWidth: true
                }

                Text {
                    text: "Clear All"
                    color: Qt.rgba(1, 1, 1, 0.5)
                    font.pixelSize: 13
                    visible: Notifications.notificationList.length > 0
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: Notifications.clearAll()
                    }
                }
            }

            // ── Grouped Notification List ──

            // Timestamp refresh trigger
            property int timeRefresh: 0
            Timer {
                interval: 30000
                running: qs.isOpen || qs.dragOffset > 0
                repeat: true
                onTriggered: notifPanel.timeRefresh++
            }

            function relativeTime(ts) {
                // Use timeRefresh to force re-evaluation
                void notifPanel.timeRefresh;
                if (!ts)
                    return "";
                let diff = Math.floor((Date.now() - ts) / 1000);
                if (diff < 30)
                    return "Just now";
                if (diff < 60)
                    return diff + "s ago";
                if (diff < 3600)
                    return Math.floor(diff / 60) + "m ago";
                if (diff < 86400)
                    return Math.floor(diff / 3600) + "h ago";
                return Math.floor(diff / 86400) + "d ago";
            }

            // Build grouped model: array of { appName, appIcon, notifications: [...] }
            property var groupedNotifications: {
                // Depend on timeRefresh so timestamps re-evaluate
                void notifPanel.timeRefresh;
                if (!qs.isOpen && qs.dragOffset <= 0)
                    return [];
                let list = Notifications.notificationList;
                let groups = {};
                let order = [];
                for (let i = 0; i < list.length; i++) {
                    let n = list[i];
                    if (!groups[n.appName]) {
                        groups[n.appName] = {
                            appName: n.appName,
                            appIcon: n.appIcon,
                            notifications: [],
                            latestTs: n.timestamp || 0
                        };
                        order.push(n.appName);
                    }
                    groups[n.appName].notifications.push(n);
                    if ((n.timestamp || 0) > groups[n.appName].latestTs) {
                        groups[n.appName].latestTs = n.timestamp || 0;
                    }
                    // Keep the most recent icon
                    if (n.appIcon && n.appIcon !== "")
                        groups[n.appName].appIcon = n.appIcon;
                }
                // Sort groups by most recent notification
                order.sort(function (a, b) {
                    return groups[b].latestTs - groups[a].latestTs;
                });
                let result = [];
                for (let j = 0; j < order.length; j++)
                    result.push(groups[order[j]]);
                return result;
            }

            // Track which app groups are expanded
            property var expandedApps: ({})

            function toggleAppExpanded(appName) {
                let copy = Object.assign({}, expandedApps);
                copy[appName] = !copy[appName];
                expandedApps = copy;
            }

            Flickable {
                id: notifFlickable
                opacity: progress
                anchors.top: notifHeader.bottom
                anchors.topMargin: 12
                height: Math.min(parent.height - y - 10, contentHeight || 0)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                clip: true
                contentHeight: notifGroupCol.implicitHeight
                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: notifGroupCol
                    width: notifFlickable.width
                    spacing: 12

                    Repeater {
                        model: notifPanel.groupedNotifications

                        delegate: ColumnLayout {
                            id: groupDelegate
                            Layout.fillWidth: true
                            spacing: 2
                            clip: true

                            property var group: modelData
                            property bool isExpanded: !!(notifPanel.expandedApps[group.appName])
                            property int stackCount: Math.min(group.notifications.length, 3) // Max 3 visible stack layers

                            // ════════════════════════════════
                            // COLLAPSED: Stacked Card View
                            // ════════════════════════════════
                            Item {
                                id: collapsedStack
                                Layout.fillWidth: true
                                property bool showCollapsed: !groupDelegate.isExpanded && group.notifications.length > 1
                                Layout.preferredHeight: showCollapsed ? stackedTopCard.height : 0
                                opacity: showCollapsed ? 1.0 : 0.0
                                visible: opacity > 0.01 || Layout.preferredHeight > 1

                                Behavior on Layout.preferredHeight {
                                    NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 350; easing.type: Easing.OutExpo }
                                }

                                // Top card (latest notification)
                                MaterialSurface {
                                    id: stackedTopCard
                                    width: parent.width
                                    height: Math.max(70, stackedCardContent.implicitHeight + 28)
                                    radius: 16

                                    property var notif: group.notifications[0]

                                    ColumnLayout {
                                        id: stackedCardContent
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 6

                                        // First row: App icon + App name + first title preview + count + timestamp
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            // App icon — only if provided
                                            Rectangle {
                                                width: 28
                                                height: 28
                                                radius: 6
                                                color: Qt.rgba(1, 1, 1, 0.1)
                                                visible: stackedTopCard.notif.appIcon !== ""

                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 20
                                                    height: 20
                                                    source: (stackedTopCard.notif.appIcon !== "" && stackedTopCard.notif.appIcon.startsWith("/")) ? "file://" + stackedTopCard.notif.appIcon : (stackedTopCard.notif.appIcon || "")
                                                    fillMode: Image.PreserveAspectFit
                                                }
                                            }

                                            Text {
                                                text: stackedTopCard.notif.appName || ""
                                                color: Qt.rgba(1, 1, 1, 0.7)
                                                font.pixelSize: 13
                                                font.bold: true
                                            }

                                            Text {
                                                text: stackedTopCard.notif.summary || ""
                                                color: Qt.rgba(1, 1, 1, 0.5)
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: notifPanel.relativeTime(stackedTopCard.notif.timestamp)
                                                color: Qt.rgba(1, 1, 1, 0.3)
                                                font.pixelSize: 11
                                            }

                                            // Count badge
                                            Rectangle {
                                                visible: group.notifications.length > 1
                                                width: stackCountText.implicitWidth + 10
                                                height: 16
                                                radius: 8
                                                color: Qt.rgba(1, 1, 1, 0.15)

                                                Text {
                                                    id: stackCountText
                                                    anchors.centerIn: parent
                                                    text: group.notifications.length
                                                    color: Qt.rgba(1, 1, 1, 0.6)
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        // Remaining notifications as compact inline rows
                                        Repeater {
                                            model: Math.min(group.notifications.length - 1, 3) // Show up to 3 more inline

                                            delegate: RowLayout {
                                                Layout.fillWidth: true
                                                Layout.leftMargin: stackedTopCard.notif.appIcon !== "" ? 38 : 0 // Align with text after icon
                                                spacing: 6

                                                Text {
                                                    text: group.notifications[index + 1].summary || ""
                                                    color: Qt.rgba(1, 1, 1, 0.7)
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    Layout.maximumWidth: parent.width * 0.4
                                                }

                                                Text {
                                                    text: group.notifications[index + 1].body || ""
                                                    color: Qt.rgba(1, 1, 1, 0.4)
                                                    font.pixelSize: 13
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                    visible: text !== ""
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: stackedCardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (group.notifications.length > 1) {
                                                notifPanel.toggleAppExpanded(group.appName);
                                            }
                                        }
                                    }

                                    // Swipe gesture on stacked card
                                    MouseArea {
                                        id: stackedSwipeMouse
                                        anchors.fill: parent
                                        property real startX: 0
                                        property bool isSwiping: false
                                        z: 1

                                        onPressed: mouse => {
                                            startX = mouse.x;
                                            isSwiping = false;
                                        }
                                        onPositionChanged: mouse => {
                                            let dx = mouse.x - startX;
                                            if (Math.abs(dx) > 10) {
                                                isSwiping = true;
                                                stackedTopCard.x = dx;
                                            }
                                        }
                                        onReleased: {
                                            if (isSwiping && Math.abs(stackedTopCard.x) > 80) {
                                                if (group.notifications.length === 1) {
                                                    Notifications.dismiss(stackedTopCard.notif.id);
                                                } else {
                                                    Notifications.dismissByApp(group.appName);
                                                }
                                            } else if (!isSwiping) {
                                                if (group.notifications.length > 1) {
                                                    notifPanel.toggleAppExpanded(group.appName);
                                                }
                                            }
                                            stackedTopCard.x = 0;
                                        }

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: 0
                                            }
                                        }
                                    }
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: stackedSwipeMouse.pressed ? 0 : 250
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            // ════════════════════════════════
                            // EXPANDED: Individual Cards
                            // ════════════════════════════════

                            // Group header (only visible when expanded and multi-notification)
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: groupDelegate.isExpanded && group.notifications.length > 1 ? 36 : 0
                                opacity: groupDelegate.isExpanded && group.notifications.length > 1 ? 1.0 : 0.0
                                visible: opacity > 0.01

                                Behavior on Layout.preferredHeight {
                                    NumberAnimation { duration: 350; easing.type: Easing.OutExpo }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: group.appName || "Unknown"
                                        color: Qt.rgba(1, 1, 1, 0.5)
                                        font.pixelSize: 13
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }

                                    // Collapse button (chevron up icon)
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: collapseHeaderMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            sourceSize: Qt.size(16, 16)
                                            source: Icons.icon("go-up-symbolic")
                                            opacity: collapseHeaderMouse.containsMouse ? 1.0 : 0.6
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 150
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: collapseHeaderMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: notifPanel.toggleAppExpanded(group.appName)
                                        }
                                    }

                                    // Clear group button (trash icon)
                                    Rectangle {
                                        width: 32
                                        height: 32
                                        radius: 16
                                        color: groupClearMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }

                                        Image {
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            sourceSize: Qt.size(16, 16)
                                            source: Icons.icon("edit-clear-all-symbolic")
                                            opacity: groupClearMouse.containsMouse ? 1.0 : 0.5
                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: 150
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: groupClearMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Notifications.dismissByApp(group.appName)
                                        }
                                    }
                                }
                            }

                            // Expanded individual cards
                            Repeater {
                                model: group.notifications.length

                                delegate: Item {
                                    id: swipeContainer
                                    Layout.fillWidth: true
                                    property bool isCardExpanded: groupDelegate.isExpanded || group.notifications.length === 1
                                    Layout.preferredHeight: isCardExpanded ? notifCard.height : 0
                                    opacity: isCardExpanded ? 1.0 : 0.0
                                    scale: isCardExpanded ? 1.0 : 0.9
                                    clip: true

                                    Behavior on Layout.preferredHeight {
                                        NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutExpo }
                                    }
                                    Behavior on scale {
                                        NumberAnimation { duration: 350; easing.type: Easing.OutExpo }
                                    }

                                    property var notif: group.notifications[index]
                                    property real swipeX: 0
                                    property bool dismissed: false

                                    // Dismiss background
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 16
                                        color: Qt.rgba(0.9, 0.3, 0.2, 0.6)
                                        visible: Math.abs(swipeContainer.swipeX) > 5

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Dismiss"
                                            color: "white"
                                            font.pixelSize: 13
                                            font.bold: true
                                            opacity: Math.min(1, Math.abs(swipeContainer.swipeX) / 80)
                                        }
                                    }

                                    MaterialSurface {
                                        id: notifCard
                                        width: swipeContainer.width
                                        x: swipeContainer.swipeX
                                        height: Math.max(70, cardContent.implicitHeight + 28)
                                        radius: 16
                                        opacity: swipeContainer.dismissed ? 0 : 1
                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 200
                                            }
                                        }

                                        Behavior on x {
                                            NumberAnimation {
                                                duration: swipeMouse.pressed ? 0 : 250
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        RowLayout {
                                            id: cardContent
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 12

                                            // App icon — only if provided
                                            Rectangle {
                                                width: 40
                                                height: 40
                                                radius: 8
                                                color: Qt.rgba(1, 1, 1, 0.1)
                                                Layout.alignment: Qt.AlignTop
                                                visible: notif.appIcon !== ""

                                                Image {
                                                    anchors.centerIn: parent
                                                    width: 28
                                                    height: 28
                                                    source: (notif.appIcon !== "" && notif.appIcon.startsWith("/")) ? "file://" + notif.appIcon : (notif.appIcon || "")
                                                    fillMode: Image.PreserveAspectFit
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignTop
                                                spacing: 3

                                                // Title + timestamp + close button row
                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8

                                                    Text {
                                                        text: notif.summary || ""
                                                        color: "white"
                                                        font.pixelSize: 14
                                                        font.bold: true
                                                        wrapMode: Text.WordWrap
                                                        Layout.fillWidth: true
                                                    }

                                                    Text {
                                                        text: notifPanel.relativeTime(notif.timestamp)
                                                        color: Qt.rgba(1, 1, 1, 0.3)
                                                        font.pixelSize: 11
                                                    }

                                                    // Close button — hover only
                                                    Item {
                                                        width: 20
                                                        height: 20
                                                        opacity: cardMouse.containsMouse ? 1.0 : 0.0
                                                        Behavior on opacity {
                                                            NumberAnimation {
                                                                duration: 150
                                                            }
                                                        }

                                                        Image {
                                                            anchors.centerIn: parent
                                                            width: 14
                                                            height: 14
                                                            sourceSize: Qt.size(16, 16)
                                                            source: Icons.icon("window-close-symbolic")
                                                            opacity: closeBtnMouse.containsMouse ? 1.0 : 0.6
                                                        }

                                                        MouseArea {
                                                            id: closeBtnMouse
                                                            anchors.fill: parent
                                                            anchors.margins: -6
                                                            hoverEnabled: true
                                                            onClicked: Notifications.dismiss(notif.id)
                                                        }
                                                    }
                                                }

                                                // Body
                                                Text {
                                                    text: notif.body || ""
                                                    color: Qt.rgba(1, 1, 1, 0.65)
                                                    font.pixelSize: 13
                                                    wrapMode: Text.WordWrap
                                                    Layout.fillWidth: true
                                                    visible: text !== ""
                                                    maximumLineCount: 3
                                                    elide: Text.ElideRight
                                                }
                                            }
                                        }

                                        // Hover detection
                                        MouseArea {
                                            id: cardMouse
                                            anchors.fill: parent
                                            z: -1
                                            hoverEnabled: true
                                        }
                                    }

                                    // Swipe gesture
                                    MouseArea {
                                        id: swipeMouse
                                        anchors.fill: parent
                                        property real startX: 0
                                        property bool isSwiping: false

                                        onPressed: mouse => {
                                            startX = mouse.x;
                                            isSwiping = false;
                                        }
                                        onPositionChanged: mouse => {
                                            let dx = mouse.x - startX;
                                            if (Math.abs(dx) > 10) {
                                                isSwiping = true;
                                                swipeContainer.swipeX = dx;
                                            }
                                        }
                                        onReleased: {
                                            if (Math.abs(swipeContainer.swipeX) > 80) {
                                                swipeContainer.swipeX = (swipeContainer.swipeX > 0 ? swipeContainer.width : -swipeContainer.width);
                                                swipeContainer.dismissed = true;
                                                dismissTimer.start();
                                            } else {
                                                swipeContainer.swipeX = 0;
                                            }
                                        }

                                        Timer {
                                            id: dismissTimer
                                            interval: 250
                                            onTriggered: Notifications.dismiss(swipeContainer.notif.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 60
                        text: "No new notifications"
                        color: Qt.rgba(1, 1, 1, 0.4)
                        font.pixelSize: 16
                        visible: Notifications.notificationList.length === 0
                    }
                }
            }
        }

        // ============================================
        // RIGHT: CONTROL CENTER (original design)
        // ============================================
        Item {
            id: controlPanel
            anchors.right: parent.right
            anchors.rightMargin: 24
            width: 400
            // Height is the sum of the vertical bands, not a hand-tuned number:
            // the header band (24 margin while closed + 32 header + 16 gap),
            // the grid's own worst-case page (8 x 76px cells + 7 x 16px gaps
            // = 720px), and the indicator band (12 gap + 28 dots) + footer
            // gap (16) + pinned bottom row (50) below it.
            //
            //   72 header band (closed)
            // + 720 grid (worst-case full page)
            // + 40 indicator band
            // + 16 footer gap
            // + 50 pinned bottom row
            // = 898
            //
            // The header band uses 24 (not 12) because the header's topMargin
            // is `12 + (12 * (1 - progress))` — 24 when the panel is closed,
            // 12 when open. The closed state is the constraint: a full 4x8
            // page must still fit. The footer gap is the 16px separation that
            // was missing, which is what made the Edit row look like part of
            // the grid when everything was flush.
            height: 72 + 720 + 40 + controlPanel.gridFooterGap
                + controlPanel.bottomRowHeight
            property bool editMode: false
            property int dragIndex: -1

            // ── Drag Proxy (visual feedback during drag) ──
            Rectangle {
                id: dragProxy
                visible: false
                z: 200
                radius: 24
                color: Qt.rgba(0.2, 0.2, 0.28, 0.9)
                border.color: Qt.rgba(1, 1, 1, 0.3)
                border.width: 1
                scale: 1.05
                opacity: 0.9

                property real grabOffsetX: 0
                property real grabOffsetY: 0
            }

            // ── Drag Tracker (invisible item for DropArea hit detection) ──
            Item {
                id: dragTracker
                width: 20
                height: 20
                visible: false
                // Lives in pageView's coordinate space so its position lines
                // up with the DropAreas under the grid. The active page sits at
                // x=0 inside the viewport whenever the strip is at rest, and
                // the strip only moves during a page swipe (which is disabled
                // in edit mode), so this frame stays correct while dragging.
                parent: pageView
                z: 300

                Drag.active: controlPanel.dragIndex >= 0
                Drag.keys: ["toggle"]
                Drag.hotSpot.x: 10
                Drag.hotSpot.y: 10

                property Item sourceDelegate: null
            }

            // Default single-page layout. Owned by quicksettings/Defaults.qml so the
            // list can be edited without scrolling through QuickSettings.qml; kept
            // on controlPanel as a property so callers continue to read
            // `controlPanel.defaultLayout` without needing to import the singleton.
            readonly property var defaultLayout: Defaults.layout

            property bool layoutApplied: false

            // ── Pagination state ──
            // `pages` is the source of truth: a JS array of pages, each an
            // array of {source, colSpan, rowSpan}. It is persisted as-is and
            // is cheap to read. The rendered `pageModels` is a parallel array
            // of ListModel objects (one per page) that the Repeater binds to;
            // it is rebuilt from `pages` by _syncPageModels() whenever pages
            // changes, so QML never has to observe a nested array directly.
            property var pages: []
            property var pageModels: []
            property int currentPage: 0
            property bool isPageSwiping: false
            // Raised by the page swipe area on an armed release, and cleared
            // shortly after. The clickable controls in a grid cell read this in
            // their onClicked / onPressAndHold: a swipe composes the press down
            // to them, and without the guard a page drag would also toggle the
            // control the gesture started on.
            property bool swallowClick: false
            // Per-press swipe tracking. Lives on the shared controlPanel so
            // simpleToggleMouse and complexHoldArea (the two cell MA flavors)
            // drive the same gesture state machine. The previous design put
            // this state on a separate topmost pageSwipeArea MA, but Qt only
            // delivers position events to the press owner — and we need the
            // cell MAs to own the press so pressAndHoldInterval and the
            // shrink animation work. The cell MAs read & write these in
            // onPressed / onPositionChanged / onReleased / onCanceled.
            property bool swipeArmed: false
            property bool swipeWasGesture: false
            property real swipeStartX: 0
            property real swipeStartY: 0
            property real swipeStartStripX: 0
            property real swipeStartTime: 0
            readonly property int pageCount: pages.length
            // Row cap for one page. Derived from the grid's own height budget
            // and the cell metrics, so it cannot disagree with either:
            // 8 rows x 76px + 7 x 16px gaps = 720px, which is exactly the
            // gridAreaHeight below. Change the cell size, the spacing, or the
            // panel's chrome and the cap follows automatically.
            readonly property int maxGridRows: Math.max(1, Math.floor(
                (gridAreaHeight + gridSpacing) / (cellSize + gridSpacing)))
            readonly property int gridColumns: 4
            // Width of one page's viewport = the grid area (panel width
            // minus the 24px Flickable margins on each side).
            readonly property real pageViewportWidth: width - 48
            readonly property real maxPageStripX: Math.max(0, (pageCount - 1) * pageViewportWidth)
            // Horizontal offset of the page strip. pageStrip binds its x to
            // this, so a swipe tracks the finger 1:1 and a release snaps back
            // to a page boundary via the Behavior on pageStrip.x.
            property real pageStripX: 0

            // The model a given page's cells bind to. Only the current page
            // and its immediate neighbours are mounted; everything else binds
            // the shared empty model, so a control-center with many pages does
            // not keep every toggle's Pipewire/Mpris/Network client alive.
            // emptyPageModel is the ListModel id declared below in this
            // component (ids are hoisted, so it resolves from here).
            function pageModelFor(index) {
                if (index < 0 || index >= controlPanel.pageCount)
                    return emptyPageModel;
                if (Math.abs(index - controlPanel.currentPage) <= 1)
                    return controlPanel.pageModels[index];
                return emptyPageModel;
            }

            // The active page's gridWrapper. The grid now lives inside a
            // per-page Repeater, so its id is not in scope for the morph code
            // (which is declared outside); each slot re-exports its wrapper as
            // `grid` and this resolves the current one. Null only if the page
            // has not been laid out yet.
            function activeGridWrapper() {
                const slot = pageSlots.itemAt(controlPanel.currentPage);
                return slot ? slot.grid : null;
            }
            // Resolve a pageView-local point to the cell at that position on
            // the current page. Returns null if the point is in a gap (inter-
            // cell band, non-grid strip). Used by the topmost swipe Handlers
            // (z:50) to route a tap / drag to the right cell even though they
            // don't own the press.
            function findCellAt(viewX, viewY) {
                const wrapper = activeGridWrapper();
                if (!wrapper) return null;
                // pageView x -> grid x. pageStrip sits at pageStripX, the
                // current page is at currentPage * pageViewportWidth inside
                // the strip.
                const gridX = viewX - pageStripX - currentPage * pageViewportWidth;
                const cell = wrapper.toggleGrid.cellAt(gridX, viewY);
                if (!cell) return null;
                return {
                    delegateItem: cell,
                    widgetBg: cell.widgetBgRef,
                    widgetLoader: cell.widgetLoaderRef,
                    model: cell.model
                };
            }
            // Vertical bands that stack inside the panel, top to bottom.
            // The panel's height is their sum, and the grid's height is
            // whatever is left after the chrome — so the bottom row can never
            // drift up into the grid area.
            //
            // The header band uses 24 (NOT 12) for its top margin, because
            // the header's topMargin is `12 + (12 * (1 - progress))` — 24 when
            // the panel is closed (where the full page must still fit), 12
            // when fully open. Using 24 means the grid is no taller than the
            // worst case needs to be.
            readonly property real headerBandHeight: 24 + 32 + 16   // margin + header + gap
            readonly property real indicatorBandHeight: 12 + 28    // gap + dots
            readonly property real bottomRowHeight: 50
            // Breathing room between the page indicator and the pinned bottom
            // row. Without it the two sit flush and read as a single bottom
            // band, which is what made the Edit row look like part of the
            // grid. This is the gap that was missing.
            readonly property real gridFooterGap: 16
            // Vertical space the grid may occupy — the panel minus the chrome
            // above and below it. Sized to the worst-case page (see
            // maxGridRows) so a full 4x8 page always fits without vertical
            // scrolling.
            readonly property real gridAreaHeight: controlPanel.height
                - headerBandHeight
                - indicatorBandHeight
                - bottomRowHeight
                - gridFooterGap
            // Cell metrics. The grid must not stretch to fill gridAreaHeight:
            // a page holding only two rows of toggles should keep its cells at
            // the real 76px and leave the rest of the page blank, rather than
            // growing each cell to consume the empty rows. These are the
            // single source of truth for cell size — the delegate's
            // Layout.preferredWidth/Height and the grid's own height all read
            // from here.
            readonly property real cellSize: (width - 48 - 3 * gridSpacing) / gridColumns
            readonly property int gridSpacing: 16

            // Height the current page's rows actually need: usedRows worth of
            // 76px cells plus the 16px gaps between them. Reuses the same
            // packing rule as pageFits(), so this matches what GridLayout does
            // with the same entries. Takes a model so it can be evaluated per
            // page (each page has a different number of rows); the default is
            // the active page, which is what the single-page callers want.
            function gridContentHeightFor(model) {
                let entries = model || controlPanel.pageModelFor(controlPanel.currentPage);
                if (!entries || entries.count === 0)
                    return 0;
                let rows = 0, col = 0, lastRowHeight = 0;
                for (let i = 0; i < entries.count; i++) {
                    const colSpan = entries.get(i).colSpan;
                    const rowSpan = entries.get(i).rowSpan;
                    if (col + colSpan > gridColumns) {
                        rows += lastRowHeight;
                        lastRowHeight = 0;
                        col = 0;
                    }
                    col += colSpan;
                    if (rowSpan > lastRowHeight) lastRowHeight = rowSpan;
                }
                let usedRows = rows + (col > 0 ? lastRowHeight : 0);
                return usedRows * cellSize + Math.max(0, usedRows - 1) * gridSpacing;
            }

            // Active page's content height, for the callers outside any page
            // Repeater (the morph's sizing and the drop hit-testing).
            readonly property real gridContentHeight: controlPanel.gridContentHeightFor(null)

            // Rejects an entry that isn't an object with a non-empty
            // source string, and clamps its spans to the 1..4 range the
            // GridLayout can honour. Returns null when the entry is junk.
            function _normalizeEntry(entry) {
                if (!entry || typeof entry !== "object" || typeof entry.source !== "string" || entry.source === "")
                    return null;
                return {
                    source: entry.source,
                    colSpan: Math.max(1, Math.min(4, parseInt(entry.colSpan) || 1)),
                    rowSpan: Math.max(1, Math.min(4, parseInt(entry.rowSpan) || 1))
                };
            }

            // Rebuilds pageModels from `pages` in place, reusing existing
            // ListModel objects. Only for wholesale page-set changes
            // (applyLayout, add/remove page) — per-entry edits go through
            // _patchModel() instead, so a resize or reorder never rebuilds
            // the model the grid is bound to.
            function _syncPageModels() {
                let next = [];
                for (let p = 0; p < controlPanel.pages.length; p++) {
                    let entries = controlPanel.pages[p];
                    let m = controlPanel.pageModels[p];
                    if (!m) {
                        m = Qt.createQmlObject('import QtQml; ListModel {}', controlPanel);
                    }
                    // Rewrite this page's model to match its source array.
                    m.clear();
                    for (let i = 0; i < entries.length; i++)
                        m.append(entries[i]);
                    next.push(m);
                }
                // Drop any surplus models from a previous, longer page set.
                for (let p = controlPanel.pages.length; p < controlPanel.pageModels.length; p++) {
                    let dead = controlPanel.pageModels[p];
                    if (dead) dead.destroy();
                }
                controlPanel.pageModels = next;
            }

            // Applies one entry mutation to a page's ListModel. Keeps `pages`
            // (the persistence source of truth) and the per-page model (what
            // the grid's Repeater binds to for that page) in step, without
            // rebuilding either.
            //
            // No active-page mirror to keep in sync any more: each page's grid
            // binds its own pageModels[index] directly, so an edit on the
            // visible page patches the model that page's cells are bound to.
            //
            //   op "set"    a = index, b = {colSpan, rowSpan}
            //   op "move"   a = from,  b = to
            //   op "append" a unused, b = entry
            //   op "remove" a = index
            function _patchModel(pageIndex, op, a, b) {
                const m = controlPanel.pageModels[pageIndex];
                if (!m) return;
                if (op === "set") {
                    m.setProperty(a, "colSpan", b.colSpan);
                    m.setProperty(a, "rowSpan", b.rowSpan);
                } else if (op === "move") {
                    m.move(a, b, 1);
                } else if (op === "append") {
                    m.append(b);
                } else if (op === "remove") {
                    m.remove(a);
                }
            }

            // Replaces the whole page set. `pages` is an array of pages,
            // each an array of {source, colSpan, rowSpan} entries. An empty
            // or non-array input falls back to the single-page default.
            function applyLayout(newPages) {
                let source = newPages;
                if (!Array.isArray(source) || source.length === 0)
                    source = [controlPanel.defaultLayout];
                let normalized = [];
                for (let p = 0; p < source.length; p++) {
                    let entries = Array.isArray(source[p]) ? source[p] : [];
                    let page = [];
                    for (let i = 0; i < entries.length; i++) {
                        let e = controlPanel._normalizeEntry(entries[i]);
                        if (e) page.push(e);
                    }
                    normalized.push(page);
                }
                controlPanel.pages = normalized;
                controlPanel.currentPage = 0;
                controlPanel.pageStripX = 0;
                controlPanel._syncPageModels();
                controlPanel.layoutApplied = true;
            }

            Connections {
                target: ConfigStore
                function onConfigLoadCompleteChanged() {
                    console.debug("[QuickSettings] Config load complete:", ConfigStore.configLoadComplete);
                    console.debug("[QuickSettings] Pages from shell:", JSON.stringify(ConfigStore.controlCenterPages));
                    if (controlPanel.layoutApplied || !ConfigStore.configLoadComplete) return;
                    if (ConfigStore.controlCenterPages && ConfigStore.controlCenterPages.length > 0) {
                        console.debug("[QuickSettings] Applying saved pages");
                        controlPanel.applyLayout(ConfigStore.controlCenterPages);
                    } else {
                        console.debug("[QuickSettings] Applying default layout");
                        controlPanel.applyLayout([controlPanel.defaultLayout]);
                    }
                }
            }

            Component.onCompleted: {
                if (ConfigStore.configLoadComplete && !controlPanel.layoutApplied) {
                    if (ConfigStore.controlCenterPages && ConfigStore.controlCenterPages.length > 0) {
                        controlPanel.applyLayout(ConfigStore.controlCenterPages);
                    } else {
                        controlPanel.applyLayout([controlPanel.defaultLayout]);
                    }
                }
            }

            Process {
                id: saveLayoutProc
                running: false
            }

            function openExpandedView(sourceRect, widgetItem, delegateRef) {
                // Defer until the panel's bloom-scale spring has settled
                // so the source widget's on-screen position is final when
                // we copy its geometry. Otherwise the morph would start
                // from a position that drifts ~15% as the panel scales
                // from 0.85 to 1.0.
                if (!qs.morphComplete) {
                    expandedOverlay.pendingSourceRect = sourceRect;
                    expandedOverlay.pendingWidgetItem = widgetItem;
                    expandedOverlay.pendingDelegateItemRef = delegateRef || null;
                    expandedOverlay.hasPendingOpen = true;
                    return;
                }
                doOpenExpandedView(sourceRect, widgetItem, delegateRef);
            }

            // Restore cell-bound geometry bindings on a previously-morphed widgetBg
            // (the one expandedOverlay.sourceItem referenced before this
            // call). Used when openExpandedView() is invoked while a
            // different toggle's expanded view is already open, so the
            // old widgetBg's broken geometry bindings get re-bound to
            // its delegateRef synchronously instead of being stranded by
            // morphCompleteTimer — whose onTriggered early-returns on
            // any morphState !== "closing", and the new widgetBg's
            // morphState is "opening" right after open() is called.
            //
            // Mirrors morphCompleteTimer.onTriggered (lines ~2925-2996).
            function restoreCellBoundBindings(prevSourceItem, prevDel) {
                if (!prevSourceItem)
                    return;
                // Skip if the previous widgetBg's cell-bound bindings are
                // already intact. morphCompleteTimer.onTriggered (lines
                // ~2925-2996) sets morphState = "idle" and clears
                // delegateItemRef = null AFTER it restores the bindings,
                // so morphState === "idle" is the authoritative signal
                // that bindings are restored. Without this gate, a clean
                // dismiss (timer fires, delegateItemRef cleared) followed
                // by opening a different toggle would call this helper
                // with prevDel = null, hit the no-delegate fallback, and
                // zero out the previous widgetBg's geometry — making the
                // previous toggle disappear from the grid. The bug stacks
                // across repeated dismiss/open cycles, each one zeroing
                // its predecessor.
                if (prevSourceItem.morphState === "idle")
                    return;
                if (prevSourceItem.morphState === "closing")
                    expandedOverlay.morphCompleteTimer.stop();
                prevSourceItem.morphState = "idle";
                prevSourceItem.scale = 1.0;
                prevSourceItem.opacity = 1.0;
                // Capture the widgetBg ref so the scale binding closure
                // can read its dragOverlay/isItemPressed without
                // resolving Repeater-child ids from outside that scope.
                let sRef = prevSourceItem;
                prevSourceItem.x = Qt.binding(function() { return prevDel.x; });
                prevSourceItem.y = Qt.binding(function() { return prevDel.y; });
                prevSourceItem.width = Qt.binding(function() { return prevDel.width; });
                prevSourceItem.height = Qt.binding(function() { return prevDel.height; });
                prevSourceItem.radius = Qt.binding(function() {
                    return (prevDel.colSpan >= 2 && prevDel.rowSpan >= 2)
                        ? 16
                        : Math.min(prevDel.width, prevDel.height) / 2;
                });
                prevSourceItem.scale = Qt.binding(function() {
                    return sRef.dragOverlay && sRef.dragOverlay.dragActive
                        ? 1.05
                        : (sRef.isItemPressed ? 0.95 : 1.0);
                });
            }

            // Helper that performs the actual snap. Public entry point is
            // openExpandedView(); replayPendingOpen() drives it after the
            // panel bloom finishes.
            function doOpenExpandedView(sourceRect, widgetItem, delegateRef) {
                // If we already had an expanded view open, restore the
                // previous widgetBg's cell-bound bindings and geometry
                // synchronously BEFORE overwriting sourceItem. Otherwise
                // the previous widgetBg's x/y/width/height/radius stay at
                // the open-morph values and morphCompleteTimer — which
                // gates on morphState === "closing" — early-returns for
                // any state other than "closing", so the new widgetBg's
                // "opening" state would strand the old bindings forever.
                if (expandedOverlay.sourceItem && expandedOverlay.sourceItem !== sourceRect) {
                    restoreCellBoundBindings(expandedOverlay.sourceItem, expandedOverlay.delegateItemRef);
                }

                // sourceRect is the widgetBg being morphed. It already
                // lives under gridWrapper at its cell-bound position
                // (Phase D no longer needs to reparent a separate card).
                // The close animation targets delegateItemRef.{x,y,width,
                // height} directly (read at close time, not captured here),
                // so the animation lands on the same value the
                // morphCompleteTimer binding restore reads — no snap.
                expandedOverlay.sourceItem = sourceRect;
                expandedOverlay.widgetItem = widgetItem;
                // Phase I: per-toggle sourceRadius capture is no longer
                // needed — the morphCompleteTimer binding restore now
                // reads the LIVE formula from delegateItem.colSpan/
                // rowSpan/width/height (Phase I Edits 1-2). Each restored
                // binding tracks its own delegateItemRef, so per-toggle
                // isolation is preserved without a captured scalar.

                // Capture the repeating-delegateItem reference at open time so
                // morphCompleteTimer (declared outside the Repeater) can
                // rebuild the cell-bound geometry bindings on the
                // morphed widgetBg after close. The Timer's onTriggered
                // runs in expandedOverlay scope and has no access to
                // delegateItem directly, so we explicitly capture it via
                // argument threading from the Repeater-delegate call
                // sites (see controlPanel.openExpandedView above).
                expandedOverlay.delegateItemRef = delegateRef || null;

                // Drive the morph on the actual widgetBg. open() writes
                // target geometry directly; the Behaviors on widgetBg
                // (gated on isMorphing) animate. The assignments in
                // open() break widgetBg's cell-bound x/y/width/height/
                // radius bindings for the duration of the morph; the
                // morphCompleteTimer restores them when the close
                // animation lands.
                expandedOverlay.open();
            }

            // Replay a deferred open() once the panel's bloom is done.
            // Wired via Connections { target: qs } inside expandedOverlay.
            function replayPendingOpen() {
                if (!expandedOverlay.hasPendingOpen)
                    return;
                let src = expandedOverlay.pendingSourceRect;
                let wid = expandedOverlay.pendingWidgetItem;
                let del = expandedOverlay.pendingDelegateItemRef;
                expandedOverlay.pendingSourceRect = null;
                expandedOverlay.pendingWidgetItem = null;
                expandedOverlay.pendingDelegateItemRef = null;
                expandedOverlay.hasPendingOpen = false;
                doOpenExpandedView(src, wid, del);
            }

            function closeExpandedView() {
                expandedOverlay.close();
            }

            // Persists the current page set. `pages` is already the canonical
            // plain-array form, so this is a straight hand-off to ConfigStore.
            function saveLayout() {
                ConfigStore.controlCenterPages = controlPanel.pages;
                ConfigStore.saveConfig();
            }

            function resetLayout() {
                applyLayout([defaultLayout]);
                saveLayout();
            }

            // ── Capacity ──
            // A page is a 4x8 grid: 4 columns, 8 rows. `_pageOccupancy`
            // reproduces GridLayout's packing so "is there room left?"
            // matches what the user actually sees:
            //   - an entry starts a fresh row when col + colSpan > columns
            //   - a row's height is the max rowSpan among its entries
            // Operates on a page's plain entry array.
            function _pageOccupancy(entries) {
                if (!entries || entries.length === 0)
                    return { rows: 0, col: 0, lastRowHeight: 0 };
                let rows = 0, col = 0, lastRowHeight = 0;
                for (let i = 0; i < entries.length; i++) {
                    const it = entries[i];
                    if (col + it.colSpan > controlPanel.gridColumns) {
                        // Close the open row at its tallest entry, then wrap.
                        rows += lastRowHeight;
                        lastRowHeight = 0;
                        col = 0;
                    }
                    col += it.colSpan;
                    if (it.rowSpan > lastRowHeight) lastRowHeight = it.rowSpan;
                }
                return { rows: rows, col: col, lastRowHeight: lastRowHeight };
            }

            // Total rows a page occupies, including its open last row.
            function pageUsedRows(entries) {
                const occ = controlPanel._pageOccupancy(entries);
                return occ.rows + (occ.col > 0 ? occ.lastRowHeight : 0);
            }

            // True when a colSpan x rowSpan entry still fits on this page.
            // Wrapping onto a new row is allowed, but the resulting row count
            // must stay within the 4x8 cap.
            function pageFits(entries, colSpan, rowSpan) {
                const occ = controlPanel._pageOccupancy(entries);
                if (occ.col === 0)
                    return occ.rows + rowSpan <= controlPanel.maxGridRows;
                const usedRows = occ.rows + occ.lastRowHeight;
                if (occ.col + colSpan <= controlPanel.gridColumns)
                    return usedRows <= controlPanel.maxGridRows;
                // Wraps: a new row starts below, so it must fit under the cap.
                return usedRows + rowSpan <= controlPanel.maxGridRows;
            }

            // Returns the index of the page a new entry of this size should
            // land on, allocating a fresh page when the current one is full.
            // Switches to that page so the user sees the new control appear.
            function ensurePageForNewEntry(colSpan, rowSpan) {
                if (controlPanel.pages.length === 0)
                    controlPanel.applyLayout([[]]);
                let idx = controlPanel.currentPage;
                if (controlPanel.pageFits(controlPanel.pages[idx], colSpan, rowSpan))
                    return idx;
                let next = controlPanel.pages.slice();
                next.push([]);
                controlPanel.pages = next;
                controlPanel._syncPageModels();
                idx = controlPanel.pages.length - 1;
                controlPanel.goToPage(idx);
                return idx;
            }

            // Appends an entry to the current page, spilling onto a new page
            // when the current one is full. Used by the Add Control popup.
            // Patches with append(), so existing cards are left untouched.
            function addEntry(source, colSpan, rowSpan) {
                let idx = controlPanel.ensurePageForNewEntry(colSpan, rowSpan);
                let next = controlPanel.pages.slice();
                let page = next[idx].slice();
                const entry = {
                    source: source,
                    colSpan: Math.max(1, Math.min(4, parseInt(colSpan) || 1)),
                    rowSpan: Math.max(1, Math.min(4, parseInt(rowSpan) || 1))
                };
                page.push(entry);
                next[idx] = page;
                controlPanel.pages = next;
                controlPanel._patchModel(idx, "append", -1, entry);
                controlPanel.saveLayout();
                return idx;
            }

            // ── Page navigation ──
            // currentPage is the data truth; pageStripX is the visual truth
            // (pageStrip.x binds to it). Both have to move together: writing
            // only currentPage left the strip where it was, so a page switch
            // was an instant content swap with no target for the strip's
            // Behavior to animate toward — that is why paging used to "snap"
            // instead of slide.
            function goToPage(index) {
                let n = controlPanel.pageCount;
                if (n === 0) return;
                let i = Math.max(0, Math.min(n - 1, index));
                controlPanel.currentPage = i;
                controlPanel.pageStripX = -i * controlPanel.pageViewportWidth;
            }

            // True when a horizontal page swipe is meaningful: there's more
            // than one page to swipe between, we're not in edit mode, an
            // expanded view isn't open, and no drag is in progress. Mirrors
            // the old pageSwipeArea.enabled clause so the gesture is a
            // no-op in exactly the same conditions.
            function enabledForSwipe() {
                return pageCount > 1
                    && !editMode
                    && !expandedOverlay.isExpanded
                    && dragIndex === -1;
            }

            // Called by the cell MA on press release. Decides whether to
            // commit the page and whether to swallow the next click.
            function _swipeCommit(endX) {
                if (!enabledForSwipe()) {
                    isPageSwiping = false;
                    return;
                }
                // Clear the swipe flag BEFORE goToPage so the snap Behavior
                // on pageStrip.x is already enabled when goToPage writes the
                // target value — otherwise the Behavior re-enables mid-write
                // and the strip flickers between the lift-off and the page
                // boundary. Flips isPageSwiping off first, then settles.
                isPageSwiping = false;
                if (swipeWasGesture)
                    swallowClick = true;
                // A "gesture" is any motion past the deadband (8px on
                // either axis), and a vertical-only swipe trips
                // swipeWasGesture without ever arming. The page must still
                // snap back to the current page boundary in that case —
                // leaving pageStripX parked mid-drag is the visible
                // "stuck on lift-off" symptom, because pageStrip.x was
                // being driven 1:1 by raw and the touchpad only emitted
                // a few delta-y events before release.
                if (swipeArmed) {
                    let dx = endX - swipeStartX;
                    let duration = Math.max(1, Date.now() - swipeStartTime);
                    let velocity = Math.abs(dx) / duration;
                    let shouldAdvance = Math.abs(dx) > 80 || velocity > 0.45;
                    if (shouldAdvance)
                        goToPage(currentPage + (dx < 0 ? 1 : -1));
                    else
                        goToPage(currentPage);
                } else if (swipeWasGesture) {
                    // Unarmed gesture: settle to the page we were on.
                    goToPage(currentPage);
                }
            }

            // Called by the cell MA when the press is canceled (grab taken
            // by the expanded view, panel closes mid-swipe, etc.). Same
            // swallow + settle as a release, but the page never advances.
            //
            // Unlike _swipeCommit, this intentionally does NOT gate on
            // enabledForSwipe(): a cancel triggered by the morph opening
            // (which flips expandedOverlay.isExpanded true) is exactly
            // when we need to clean up — the cell MA's press was just
            // stolen by the morph overlay, and leaving pageStripX parked
            // mid-drag is the visible "grid stuck after expandedUI closes"
            // bug. enabledForSwipe() still gates the tracking path in
            // onPositionChanged, so a no-longer-eligible gesture stops
            // tracking and just settles on cancel.
            function _swipeCancel() {
                if (swipeWasGesture)
                    swallowClick = true;
                if (swipeArmed)
                    goToPage(currentPage);
                isPageSwiping = false;
            }

            function addPage() {
                let next = controlPanel.pages.slice();
                next.push([]);
                controlPanel.pages = next;
                controlPanel._syncPageModels();
                controlPanel.goToPage(controlPanel.pages.length - 1);
                controlPanel.saveLayout();
            }

            // Removes a page and its controls. Refuses to remove the last
            // one — an empty control center would have nothing to show.
            function removePage(index) {
                if (controlPanel.pages.length <= 1) return;
                let idx = Math.max(0, Math.min(controlPanel.pages.length - 1, index));
                let next = controlPanel.pages.slice();
                next.splice(idx, 1);
                controlPanel.pages = next;
                controlPanel._syncPageModels();
                controlPanel.goToPage(Math.min(idx, controlPanel.pages.length - 1));
                controlPanel.saveLayout();
            }

            // Moves an entry within its page (edit-mode reorder). Patches the
            // models with a move() so the delegates are reordered rather than
            // destroyed and rebuilt.
            function moveEntry(pageIndex, from, to) {
                let next = controlPanel.pages.slice();
                let page = next[pageIndex].slice();
                if (from < 0 || from >= page.length || to < 0 || to >= page.length) return;
                page.splice(to, 0, page.splice(from, 1)[0]);
                next[pageIndex] = page;
                controlPanel.pages = next;
                controlPanel._patchModel(pageIndex, "move", from, to);
            }

            // Removes one entry from a page (edit-mode delete). Patches with
            // remove(), so only the deleted card is torn down.
            function removeEntry(pageIndex, index) {
                let next = controlPanel.pages.slice();
                let page = next[pageIndex].slice();
                if (index < 0 || index >= page.length) return;
                page.splice(index, 1);
                next[pageIndex] = page;
                controlPanel.pages = next;
                controlPanel._patchModel(pageIndex, "remove", index);
            }

            // Resizes one entry in place (edit-mode resize handle). Patches
            // with setProperty(), so the delegate survives and the resized
            // card's colSpan/rowSpan bindings (and the morph's cell-bound
            // radius formula) update in place.
            function resizeEntry(pageIndex, index, colSpan, rowSpan) {
                let next = controlPanel.pages.slice();
                let page = next[pageIndex].slice();
                if (index < 0 || index >= page.length) return;
                const entry = {
                    source: page[index].source,
                    colSpan: Math.max(1, Math.min(4, parseInt(colSpan) || 1)),
                    rowSpan: Math.max(1, Math.min(4, parseInt(rowSpan) || 1))
                };
                page[index] = entry;
                next[pageIndex] = page;
                controlPanel.pages = next;
                controlPanel._patchModel(pageIndex, "set", index, entry);
            }

            // The live model backing the currently visible page.
            readonly property var currentModel: pageModels.length > 0
                ? pageModels[Math.min(currentPage, pageModels.length - 1)]
                : null

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: "transparent"
                transformOrigin: Item.TopRight
                scale: panelContainer.bloomScale

                // ── Edit Mode Header ──
                Item {
                    id: controlHeader
                    anchors.top: parent.top
                    anchors.topMargin: 12 + (12 * (1 - progress))
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24 + (16 - 24) * (1 - progress)
                    height: 32
                    opacity: progress

                    // ── Status Icons (visible once morph completes; latched to avoid spring oscillation flicker) ──
                    Row {
                        id: morphStatusIcons
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        spacing: 12
                        visible: qs.morphComplete

                        // 1. Tray Icons
                        Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: SystemTray.items
                    delegate: Item {
                        width: 20
                        height: 20
                        Image {
                            id: trayIconMorph
                            anchors.fill: parent
                            sourceSize: Qt.size(24, 24)
                            fillMode: Image.PreserveAspectFit
                            source: modelData.icon && modelData.icon !== "" ? (modelData.icon.startsWith("/") ? "file://" + modelData.icon : modelData.icon.startsWith("image://") || modelData.icon.startsWith("file://") ? modelData.icon : "image://icon/" + modelData.icon) : ""
                        }
                    }
                            }
                        }

                        // Replicate Status Icons from StatusBar.qml
                        // Bluetooth
                        Item {
                            width: (Bluetooth.bluetoothEnabled && Bluetooth.bluetoothConnected) ? 20 : 0
                            height: 20
                            visible: width > 0
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: btIconMorph
                                anchors.fill: parent
                                source: Icons.icon(Bluetooth.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
                                sourceSize: Qt.size(24, 24)
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: btIconMorph
                                source: btIconMorph
                                color: "white"
                            }
                        }

                        // Network
                        Item {
                            width: Network.networkConnected ? 20 : 0
                            height: 20
                            visible: width > 0
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: networkIconMorph
                                anchors.fill: parent
                                source: {
                                    if (Network.networkType === "ethernet") {
                                        return Icons.icon("network-wired-symbolic");
                                    }

                                    let levels = ["none", "weak", "ok", "good", "excellent"];
                                    let level = levels[Network.networkSignalLevel] || "none";
                                    return Icons.icon("network-wireless-signal-" + level + "-symbolic");
                                }
                                sourceSize: Qt.size(24, 24)
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: networkIconMorph
                                source: networkIconMorph
                                color: "white"
                            }
                        }

                        // Battery
                        Row {
                            spacing: 6
                            anchors.verticalCenter: parent.verticalCenter
                            Item {
                                width: 20
                                height: 20
                                anchors.verticalCenter: parent.verticalCenter
                                Image {
                                    id: battIconMorph
                                    anchors.fill: parent
                                    source: {
                                        let isCharging = Battery.batteryStatus === "Charging";
                                        let pct = Battery.batteryPct;
                                        if (pct < 0)
                                            return Icons.icon("battery-missing-symbolic");
                                        let level = Math.max(0, Math.min(100, Math.round(pct / 10) * 10));
                                        let sLevel = (level < 100 ? (level < 10 ? "00" : "0") : "") + level;
                                        let name = "battery-" + sLevel;
                                        if (isCharging)
                                            name += "-charging";
                                        name += "-symbolic";
                                        return Icons.icon(name);
                                    }
                                    sourceSize: Qt.size(24, 24)
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: battIconMorph
                                    source: battIconMorph
                                    color: "white"
                                }
                            }
                            Text {
                                text: Battery.batteryPct >= 0 ? Battery.batteryPct + "%" : "—"
                                color: "white"
                                font.pixelSize: 15
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // ── Status Cluster (visible once morph completes; latched to avoid spring oscillation flicker) ──
                    // (Edit button used to live here; it's been moved to the
                    // bottom of the grid in the new design.)
                }
                // Shared empty model for pages outside the mount window
                // (see controlPanel.pageModelFor). A Repeater bound to an
                // empty ListModel instantiates zero delegates, so a distant
                // page costs nothing until it is dragged near.
                ListModel {
                    id: emptyPageModel
                }

                // ── Customizable Quick toggles grid ──
                // A clipping viewport one page wide, with the whole page
                // strip translated inside it (see pageStrip below). Vertical
                // scrolling is gone: a full 4x8 page is 720px and always
                // fits the panel's vertical budget now that the bottom row
                // is pinned as chrome.
                //
                // pageView itself is NOT translated and deliberately has no
                // horizontal anchors — it is a fixed-width window. It was
                // previously anchored left+right AND bound to pageStripX, and
                // a horizontal anchor silently wins over a bound x, so every
                // swipe wrote pageStripX and moved nothing. Only the strip
                // inside moves now.
                Item {
                    id: pageView
                    anchors.top: controlHeader.bottom
                    anchors.topMargin: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: controlPanel.pageViewportWidth
                    height: controlPanel.gridAreaHeight
                    opacity: progress // Non-morphing content fades in
                    // Clipped so the neighbouring page sliding in is cut off
                    // at the panel edge instead of bleeding over the chrome.
                    // Dropped while expanded: the morph card grows past this
                    // box, so clipping it would cut the expanded view off.
                    clip: !expandedOverlay.isExpanded

                    // ── The sliding page strip ──
                    // Holds every page side by side, each offset by its
                    // index, and slides by -currentPage * pageViewportWidth.
                    // goToPage() writes pageStripX, so a page switch now has
                    // a real target for the Behavior to animate toward
                    // instead of teleporting the content.
                    Item {
                        id: pageStrip
                        x: controlPanel.pageStripX
                        width: controlPanel.pageCount * controlPanel.pageViewportWidth
                        height: parent.height
                        Behavior on x {
                            enabled: !controlPanel.isPageSwiping
                            NumberAnimation {
                                duration: 320
                                easing.type: Easing.OutExpo
                            }
                        }

                        // ── Per-page slots ──
                        // One slot per page, laid out side by side INSIDE the
                        // strip; the strip's own x is what slides. Each slot
                        // owns its own gridWrapper + GridLayout bound to its
                        // own pageModels[index], so a swipe reveals the real
                        // neighbouring page instead of empty space.
                        //
                        // gridWrapper is a Repeater-child id and therefore NOT
                        // visible to code outside this Repeater (the morph is),
                        // so each slot re-exports it as `grid` and callers
                        // reach the active one through
                        // controlPanel.activeGridWrapper().
                        Repeater {
                            id: pageSlots
                            model: controlPanel.pageCount

                            delegate: Item {
                                id: pageSlot
                                required property int index
                                // Page i sits at x = i * viewportWidth within
                                // the strip, which the strip's x translates.
                                x: index * controlPanel.pageViewportWidth
                                width: controlPanel.pageViewportWidth
                                height: controlPanel.gridAreaHeight
                                // Re-export for out-of-Repeater lookups.
                                readonly property var grid: gridWrapper

                    // Grid. gridWrapper is referenced by the expanded-view morph
                    // code outside this Repeater, so it stays a single shared
                    // parent that the active page's widgetBg instances reparent
                    // into.
                    //
                    // Its height is this page's *content* height, not the full
                    // page. Filling the page made GridLayout distribute the
                    // leftover height across its rows, stretching every cell —
                    // so a page with two rows of toggles rendered them as tall
                    // pills filling all 8 rows.
                    // Cells now stay at their real 76px and the remainder of
                    // the page is simply empty, top-aligned.
                    Item {
                        id: gridWrapper
                        width: parent.width
                        height: controlPanel.gridContentHeightFor(controlPanel.pageModelFor(pageSlot.index))

                        GridLayout {
                            id: toggleGrid
                            width: parent.width
                            height: parent.height
                            columns: controlPanel.gridColumns
                            rowSpacing: controlPanel.gridSpacing
                            columnSpacing: controlPanel.gridSpacing

                            Repeater {
                                // Binds this page's own model, or the shared
                                // empty model when the page is outside the
                                // mount window (currentPage +/- 1).
                                model: controlPanel.pageModelFor(pageSlot.index)
                                delegate: Item {
                                    id: delegateItem
                                    property int itemIndex: index
                                    property bool isDragging: controlPanel.dragIndex === index
                                    // Pointers to the sibling widgetBg (the morph
                                    // container) and widgetLoader (the loaded
                                    // toggle), so findCellAt() can resolve a
                                    // pageView-local point back to the cell it
                                    // landed on. widgetBg is reparented to
                                    // gridWrapper, but its id is resolvable in
                                    // the delegate's scope.
                                    property Item widgetBgRef: widgetBg
                                    property Loader widgetLoaderRef: widgetLoader
                                    // Phase I: declare colSpan/rowSpan as real QML properties so they're
                                        // accessible from morphCompleteTimer's expandedOverlay scope (where
                                        // `model` is not resolvable as a JS-accessible field — see the
                                        // Phase G3 reliability concern at lines ~1242-1247). Without this,
                                        // the binding restore cannot rebuild the cell-bound radius formula
                                        // after a close cycle, and resizing the toggle in edit mode does
                                        // not update the radius because the restored binding is a captured
                                        // scalar (s.sourceRadius) rather than a live formula.
                                        //
                                        // The bindings track model.colSpan/rowSpan via the Repeater context
                                        // property, so they update immediately when the resize
                                        // handle writes a new value via resizeEntry().
                                        property int colSpan: model.colSpan
                                        property int rowSpan: model.rowSpan

                                        // Keep the layout slot full size so it acts as a placeholder
                                        Layout.columnSpan: model.colSpan
                                        Layout.rowSpan: model.rowSpan
                                        Layout.fillWidth: true
                                        property real colWidth: Math.max(0, (toggleGrid.width - (3 * toggleGrid.columnSpacing)) / 4)
                                        Layout.preferredWidth: (model.colSpan * colWidth) + ((model.colSpan - 1) * toggleGrid.columnSpacing)
                                        Layout.minimumWidth: Layout.preferredWidth
                                        Layout.maximumWidth: Layout.preferredWidth
                                        Layout.preferredHeight: (model.rowSpan * controlPanel.cellSize) + ((model.rowSpan - 1) * controlPanel.gridSpacing)

                                        Behavior on x {
                                            enabled: controlPanel.editMode
                                            NumberAnimation {
                                                duration: 300
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                        Behavior on y {
                                            enabled: controlPanel.editMode
                                            NumberAnimation {
                                                duration: 300
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Timer {
                                            id: moveThrottle
                                            interval: 200
                                        }

                                        DropArea {
                                            anchors.fill: parent
                                            keys: ["toggle"]
                                            enabled: controlPanel.editMode && !delegateItem.isDragging
                                            onEntered: drag => {
                                                if (!moveThrottle.running && dragTracker.sourceDelegate && dragTracker.sourceDelegate.itemIndex !== delegateItem.itemIndex) {
                                                    let fromIdx = dragTracker.sourceDelegate.itemIndex;
                                                    let targetIdx = delegateItem.itemIndex;
                                                    // Reorder within the current page only.
                                                    controlPanel.moveEntry(controlPanel.currentPage, fromIdx, targetIdx);
                                                    controlPanel.dragIndex = targetIdx;
                                                    moveThrottle.start();
                                                }
                                            }
                                        }

                                        Rectangle {
                                            id: widgetBg
                                            parent: gridWrapper
                                            // ── Phase D: widgetBg IS the morph container. ──
                                            // (Previously a separate `expandedCard` Rectangle was
                                            // reparented to gridWrapper and duplicated the visual
                                            // surface during the morph. The user rejected that
                                            // pattern — they want the actual toggle to morph into
                                            // the expanded view, not be hidden while a duplicate
                                            // container grows in its place. Now widgetBg itself
                                            // animates geometry/radius while widgetLoader content
                                            // fades out and the new expandedLoader content fades
                                            // in inside this same widget.)
                                            property bool isCircle: model.colSpan === 1 && model.rowSpan === 1
                                            // 4-state geometry-animation machine (lives on the
                                            // morph container now, not on a separate card).
                                            //   idle      - geometry assignments instant (default)
                                            //   opening   - Behaviors animating toward expanded bounds
                                            //   open      - holding expanded geometry; animations idle
                                            //   closing   - Behaviors animating back to source bounds
                                            property string morphState: "idle"
                                            // Phase F: gate the geometry Behaviors on the local
                                            // morphState (a value we control explicitly via
                                            // open/close/timer) rather than on expandedOverlay.isExpanded
                                            // (a sibling flag that flips the moment close() runs).
                                            // Coupling made close() render the shrink instantly because
                                            // the Behavior's `enabled:` was already false by the time
                                            // we wrote the geometry.
                                            property bool isMorphing: morphState !== "idle"
                                            width: delegateItem.width
                                            height: delegateItem.height
                                            x: delegateItem.x
                                            y: delegateItem.y
                                            radius: (model.colSpan >= 2 && model.rowSpan >= 2) ? 16 : Math.min(width, height) / 2
                                            color: "transparent"
                                            clip: true
                                            // Container opacity is NOT animated — the container
                                            // stays at full opacity so the user sees the toggle
                                            // actually morph. Only the inner content
                                            // (widgetLoader + toggleChrome) fades out, while
                                            // expandedLoader fades in.

                                            MaterialSurface {
                                                id: bgSurface
                                                anchors.fill: parent
                                                radius: parent.radius
                                                // Phase F: hide the colored backdrop of any
                                                // non-morph cell while an expanded view is
                                                // showing. Without this, the bgSurface stays
                                                // at full opacity and the user sees colored
                                                // round/pill shapes around the expanded card.
                                                // The morph target cell stays visible (it's the
                                                // source); only the OTHER cells fade out.
                                                opacity: (expandedOverlay.isExpanded && expandedOverlay.sourceItem !== widgetBg) ? 0.0 : 1.0
                                                Behavior on opacity {
                                                    enabled: !controlPanel.editMode
                                                    NumberAnimation {
                                                        duration: 400
                                                        easing.type: Easing.OutExpo
                                                    }
                                                }
                                                // Phase J: when this widgetBg is the morph source, the
                                                // expanded component fills the card and the bgSurface
                                                // should render the panel's frosted material
                                                // (Frosted Glass inactive = 10% white + gradient
                                                // border), NOT the toggle's active-state color
                                                // (Frosted Glass active = white 80%, which produces
                                                // the solid-white expanded background the user
                                                // reported). The expanded component provides its
                                                // own content chrome (ExpandedHeader iconBadge,
                                                // etc.) — it does not depend on bgSurface.fgColor
                                                // inversion, so suppressing isActive here has no
                                                // content-side effect.
                                                //
                                                // The original two early-return guards stay: empty
                                                // widgetLoader (toggle still loading) and the
                                                // pill-shape simplification (colSpan >= 2 + simple
                                                // toggle never renders as active — pill, not dot).
                                                isActive: {
                                                    if (!widgetLoader.item)
                                                        return false;
                                                    if (widgetLoader.item.isSimpleToggle && model.colSpan >= 2)
                                                        return false;
                                                    if (expandedOverlay.isExpanded && expandedOverlay.sourceItem === widgetBg)
                                                        return false;
                                                    return !!widgetLoader.item.isActive;
                                                }
                                                accentColor: (widgetLoader.item && widgetLoader.item.activeColor) ? widgetLoader.item.activeColor : (Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
                                            }

// ── Geometry Behaviors (Phase E consolidated) ──
// One Behavior per property, gated on the disjunction of morph and
// edit-mode. Animation duration/easing picks based on which mode is
// active (morph wins if both). Phase D's dual-block pattern (one
// Behavior gated on editMode, a parallel one gated on isMorphing) had
// a QML gotcha where the parallel Behaviors' enabled conditions could
// briefly read stale at the moment of property change, causing the
// animation to be skipped. A single Behavior with conditional
// animation params avoids that interaction.
Behavior on width {
    enabled: widgetBg.isMorphing || controlPanel.editMode
    NumberAnimation {
        duration: widgetBg.isMorphing ? 400 : 300
        easing.type: widgetBg.isMorphing ? Easing.OutExpo : Easing.OutCubic
    }
}
Behavior on height {
    enabled: widgetBg.isMorphing || controlPanel.editMode
    NumberAnimation {
        duration: widgetBg.isMorphing ? 400 : 300
        easing.type: widgetBg.isMorphing ? Easing.OutExpo : Easing.OutCubic
    }
}
Behavior on x {
    enabled: widgetBg.isMorphing || controlPanel.editMode
    NumberAnimation {
        duration: widgetBg.isMorphing ? 400 : 300
        easing.type: widgetBg.isMorphing ? Easing.OutExpo : Easing.OutCubic
    }
}
Behavior on y {
    enabled: widgetBg.isMorphing || controlPanel.editMode
    NumberAnimation {
        duration: widgetBg.isMorphing ? 400 : 300
        easing.type: widgetBg.isMorphing ? Easing.OutExpo : Easing.OutCubic
    }
}
Behavior on radius {
    enabled: widgetBg.isMorphing || controlPanel.editMode
    NumberAnimation {
        duration: widgetBg.isMorphing ? 400 : 300
        easing.type: widgetBg.isMorphing ? Easing.OutExpo : Easing.OutCubic
    }
}

                                            property bool isItemPressed: {
                                                if (controlPanel.editMode)
                                                    return false;
                                                if (widgetLoader.item && widgetLoader.item.isSimpleToggle)
                                                    return simpleToggleMouse.pressed;
                                                if (widgetLoader.item && "isPressed" in widgetLoader.item)
                                                    return widgetLoader.item.isPressed;
                                                return complexHoldArea.pressed;
                                            }
                                            // Phase G3 hotfix: alias the
                                            // EditOverlay id so
                                            // morphCompleteTimer (declared
                                            // in expandedOverlay scope,
                                            // outside the Repeater) can
                                            // read dragActive when
                                            // restoring the scale binding
                                            // after a close. widgetOverlay
                                            // is a Repeater-child id and
                                            // is not hoisted into the
                                            // Timer's scope; this property
                                            // re-exports it from widgetBg
                                            // (whose reference is already
                                            // stored in
                                            // expandedOverlay.sourceItem,
                                            // so any code with `s` can do
                                            // `s.dragOverlay.dragActive`).
                                            property var dragOverlay: widgetOverlay

                                            scale: widgetOverlay.dragActive ? 1.05 : (isItemPressed ? 0.95 : 1.0)
                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: 150
                                                    easing.type: Easing.OutCubic
                                                }
                                            }

                                            layer.enabled: qs.isOpen || qs.dragOffset > 0
                                            layer.effect: OpacityMask {
                                                maskSource: Rectangle {
                                                    width: widgetBg.width
                                                    height: widgetBg.height
                                                    radius: widgetBg.radius
                                                }
                                            }

                                            MouseArea {
                                                id: complexHoldArea
                                                anchors.fill: parent
                                                // Own the press for complex (non-simple) widgets the
                                                // same way simpleToggleMouse does for simple ones: stop
                                                // composition so jitter within the cell does not
                                                // re-target the press to a neighbouring cell and
                                                // cancel the in-flight pressAndHold timer. The widget's
                                                // own inner MAs (e.g. deviceSliderArea) sit lower in the
                                                // z-stack and intercept the press only for their own
                                                // slider / click handling, after which the cell regains
                                                // the press on release.
                                                propagateComposedEvents: false
                                                // See simpleToggleMouse for the rationale: without
                                                // this, the z:50 pageSwipeHandlers DragHandler
                                                // swallows mouse events and this MA never sees
                                                // onPressed (and therefore never fires
                                                // onPressAndHold → expanded view). Touch path
                                                // never needed this; mouse does from Qt 6.5+.
                                                preventStealing: true
                                                // Same guard as simpleToggleMouse: disable while expanded
                                                // so this MouseArea doesn't intercept clicks meant for
                                                // the expandedLoader's inner controls (and so
                                                // complexHoldArea.pressed doesn't return true during
                                                // the expanded state, which would flip isItemPressed
                                                // true and trigger an unwanted scale-press animation
                                                // on the morphed card).
                                                enabled: !controlPanel.editMode
                                                    && widgetLoader.item !== null
                                                    && widgetLoader.item.hasExpandedView === true
                                                    && widgetLoader.item.isSimpleToggle !== true
                                                    && !expandedOverlay.isExpanded
                                                pressAndHoldInterval: 300
                                                // ── Long-press only ──
                                                // Page swipes are now tracked by the
                                                // z:50 DragHandler in pageView (see
                                                // pageSwipeHandlers). This MA still owns
                                                // the press for pressAndHoldInterval and
                                                // the slider's inner deviceSliderArea, but
                                                // no longer tracks the drag — the
                                                // DragHandler does that without stealing
                                                // the grab (preventStealing above keeps
                                                // this MA's press in its own hands).
                                                onPressAndHold: {
                                                    // A horizontal swipe past the 8 px
                                                    // motion threshold (Handlers) has
                                                    // already claimed the gesture — drop
                                                    // the hold, the user is paging. Also
                                                    // swallow the next click so the
                                                    // underlying control doesn't toggle
                                                    // on release.
                                                    if (controlPanel.swipeArmed
                                                            || controlPanel.swipeWasGesture) {
                                                        controlPanel.swallowClick = true;
                                                        return;
                                                    }
                                                    // NOTE: do NOT check swallowClick here.
                                                    // That flag exists to swallow the next
                                                    // *click* on the cell the user landed
                                                    // on after a swipe, and is cleared in
                                                    // onClicked below. A long-press is a
                                                    // deliberate action — opening the
                                                    // expanded view — and must not be
                                                    // blocked by a stale swallowClick from
                                                    // a previous swipe, otherwise the user
                                                    // would need two holds to open the
                                                    // expanded view after every page swipe.
                                                    controlPanel.openExpandedView(widgetBg, widgetLoader.item, delegateItem);
                                                }
                                            }

                                            // ── Toggle's own content (the compact view) ──
                                            // Fades out during the morph so the expanded view's
                                            // content can fade in inside the same widgetBg.
                                            // Edit-mode guard keeps edit-mode direct opacity
                                            // writes instant (the drag-ghost sets opacity on
                                            // widgetBg directly, not on widgetLoader, so this
                                            // Behavior isn't actually triggered by the ghost,
                                            // but the guard is kept for symmetry with the
                                            // earlier phases' pattern).
                                            Loader {
                                                id: widgetLoader
                                                anchors.fill: parent
                                                active: qs.isOpen || qs.dragOffset > 0
                                                asynchronous: true
                                                property var modelData: model
                                                source: model.source || ""
                                                opacity: expandedOverlay.isExpanded ? 0.0 : 1.0
                                                Behavior on opacity {
                                                    enabled: !controlPanel.editMode
                                                    NumberAnimation {
                                                        duration: 400
                                                        easing.type: Easing.OutExpo
                                                    }
                                                }
                                                onLoaded: {
                                                    // Connect expandRequested signal for widgets that handle their own hold detection.
                                                    // Gate on !expandedOverlay.isExpanded so a press that
                                                    // propagates through the morphed card into the widget's
                                                    // internal hold MA (VolumeSlider holdTimer, BrightnessSlider
                                                    // holdTimer, MediaWidget bgMouseArea) cannot re-trigger
                                                    // openExpandedView while an expanded view is already showing.
                                                    if (item && item.expandRequested) {
                                                        item.expandRequested.connect(function () {
                                                            // Complex widgets (VolumeSlider,
                                                            // BrightnessSlider, MediaWidget) run
                                                            // their own hold timers on a press that a
                                                            // page swipe composes down to them, so a
                                                            // slow drag can request the expanded view
                                                            // mid-gesture. Drop it while the pager owns
                                                            // the gesture.
                                                            //
                                                            // NOTE: do NOT check swallowClick here.
                                                            // That flag is owned by onClicked (the
                                                            // cell MA's click handler) to swallow the
                                                            // next click on the cell the user landed
                                                            // on after a swipe. Checking it here would
                                                            // block the first long-press after a swipe
                                                            // from opening the expanded view — the
                                                            // holdTimer fires once, expandRequested
                                                            // returns, and the user has to hold a
                                                            // second time for the timer to fire again.
                                                            // The page-swipe guard
                                                            // (swipeArmed/swipeWasGesture) below is
                                                            // what actually prevents a slow drag from
                                                            // triggering the expanded view mid-gesture.
                                                            if (controlPanel.swipeArmed
                                                                    || controlPanel.swipeWasGesture) {
                                                                return;
                                                            }
                                                            if (!controlPanel.editMode && item.hasExpandedView && !expandedOverlay.isExpanded) {
                                                                controlPanel.openExpandedView(widgetBg, item, delegateItem);
                                                            }
                                                        });
                                                    }
                                                }
                                            }

                                            // ── Shell-provided toggle chrome for simple toggles ──
                                            // If the loaded widget has `isSimpleToggle: true`, the shell
                                            // handles all styling (active bg, icon, label, click).
                                            // Same opacity-crossfade as widgetLoader: chrome fades
                                            // out during the morph, expandedView fades in on top.
                                            Rectangle {
                                                id: toggleChrome
                                                anchors.fill: parent
                                                visible: widgetLoader.item && widgetLoader.item.isSimpleToggle === true
                                                radius: widgetBg.radius
                                                color: "transparent"
                                                opacity: expandedOverlay.isExpanded ? 0.0 : 1.0
                                                Behavior on opacity {
                                                    enabled: !controlPanel.editMode
                                                    NumberAnimation {
                                                        duration: 400
                                                        easing.type: Easing.OutExpo
                                                    }
                                                }
                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: 200
                                                    }
                                                }

                                                // ── Layout for non-2x2 toggles (1x1 circles, 2x1 pills) ──
                                                GridLayout {
                                                    visible: !(model.colSpan === 2 && model.rowSpan === 2)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    x: 14
                                                    width: parent.width - x - 14

                                                    columns: model.colSpan > model.rowSpan ? 2 : 1
                                                    rowSpacing: 8
                                                    columnSpacing: 12

                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignCenter
                                                        width: (model.colSpan > 1) ? 48 : 24
                                                        height: (model.colSpan > 1) ? 48 : 24
                                                        radius: width / 2
                                                        color: "transparent"

                                                        MaterialSurface {
                                                            id: innerSurface
                                                            anchors.fill: parent
                                                            radius: parent.radius
                                                            visible: model.colSpan > 1
                                                            isToggleCircle: true
                                                            isActive: widgetLoader.item ? !!widgetLoader.item.isActive : false
                                                            accentColor: (widgetLoader.item && widgetLoader.item.activeColor) ? widgetLoader.item.activeColor : (Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
                                                        }

                                                        Item {
                                                            anchors.centerIn: parent
                                                            width: 28
                                                            height: 28

                                                            Image {
                                                                id: chromeIcon
                                                                anchors.fill: parent
                                                                sourceSize: Qt.size(28, 28)
                                                                source: (widgetLoader.item && widgetLoader.item.iconSource) || ""
                                                                visible: false
                                                            }
                                                            ColorOverlay {
                                                                anchors.fill: chromeIcon
                                                                source: chromeIcon
                                                                color: model.colSpan > 1 ? innerSurface.iconColor : bgSurface.iconColor
                                                            }
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        visible: model.colSpan > 1
                                                        Layout.alignment: model.colSpan > model.rowSpan ? Qt.AlignVCenter | Qt.AlignLeft : Qt.AlignHCenter
                                                        Layout.fillWidth: model.colSpan > model.rowSpan
                                                        spacing: 0

                                                        Text {
                                                            text: (widgetLoader.item && (widgetLoader.item.titleText !== undefined ? widgetLoader.item.titleText : widgetLoader.item.toggleName)) || ""
                                                            color: bgSurface.fgColor
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            Layout.fillWidth: true
                                                            horizontalAlignment: model.colSpan > model.rowSpan ? Text.AlignLeft : Text.AlignHCenter
                                                            elide: Text.ElideRight
                                                        }

                                                        Text {
                                                            text: (widgetLoader.item && widgetLoader.item.subtitleText) || ""
                                                            visible: text !== ""
                                                            color: bgSurface.fgColor
                                                            font.pixelSize: 13
                                                            font.bold: true
                                                            Layout.fillWidth: true
                                                            horizontalAlignment: model.colSpan > model.rowSpan ? Text.AlignLeft : Text.AlignHCenter
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }

                                                // ── Layout for 2x2 toggles ──
                                                Item {
                                                    anchors.fill: parent
                                                    visible: model.colSpan === 2 && model.rowSpan === 2

                                                    Rectangle {
                                                        id: toggleCircle
                                                        width: 48
                                                        height: 48
                                                        radius: 24
                                                        anchors.top: parent.top
                                                        anchors.topMargin: 16
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 16
                                                        color: "transparent"

                                                        MaterialSurface {
                                                            id: circleSurface
                                                            anchors.fill: parent
                                                            radius: parent.radius
                                                            isToggleCircle: true
                                                            isActive: widgetLoader.item ? !!widgetLoader.item.isActive : false
                                                            accentColor: (widgetLoader.item && widgetLoader.item.activeColor) ? widgetLoader.item.activeColor : (Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
                                                        }

                                                        Item {
                                                            anchors.centerIn: parent
                                                            width: 28
                                                            height: 28

                                                            Image {
                                                                id: circleIcon
                                                                anchors.fill: parent
                                                                sourceSize: Qt.size(28, 28)
                                                                source: (widgetLoader.item && widgetLoader.item.iconSource) || ""
                                                                visible: false
                                                            }
                                                            ColorOverlay {
                                                                anchors.fill: circleIcon
                                                                source: circleIcon
                                                                color: circleSurface.iconColor
                                                            }
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: 16
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 16
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: 16
                                                        spacing: 0

                                                        Text {
                                                            text: (widgetLoader.item && (widgetLoader.item.titleText !== undefined ? widgetLoader.item.titleText : widgetLoader.item.toggleName)) || ""
                                                            color: "white"
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }

                                                        Text {
                                                            text: (widgetLoader.item && widgetLoader.item.subtitleText) || ""
                                                            visible: text !== ""
                                                            color: Qt.rgba(1, 1, 1, 0.6)
                                                            font.pixelSize: 13
                                                            font.bold: true
                                                            Layout.fillWidth: true
                                                            elide: Text.ElideRight
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: simpleToggleMouse
                                                    anchors.fill: parent
                                                    // Own the press lifecycle for this cell: stop the
                                                // composed event from propagating further down. With
                                                // propagateComposedEvents: true (the previous value),
                                                // a small finger jitter past the cell's boundary
                                                // would re-target the press to whichever cell is
                                                // currently under the finger, cancelling any in-flight
                                                // pressAndHold timer and dropping `pressed` mid-gesture.
                                                // That is what made long-press flaky and what made the
                                                // shrink animation on tap unreliable. Disabling
                                                // composition means this MA is the unambiguous owner of
                                                // the press for as long as the finger stays in it.
                                                propagateComposedEvents: false
                                                    // Keep this MA's press away from the z:50
                                                    // pageSwipeHandlers DragHandler. Without it
                                                    // the DragHandler swallows mouse events on
                                                    // their way through Qt's handler system and
                                                    // this cell MA never sees onPressed — touch
                                                    // works because Qt's touch path never needed
                                                    // this; mouse needs it from Qt 6.5+ on. The
                                                    // DragHandler still observes drag motion
                                                    // (it just can't take the press), so page
                                                    // swipes still track the finger.
                                                    preventStealing: true
                                                    // Phase G2: disable while expanded. toggleChrome's
                                                    // opacity:0 doesn't disable input, so without this
                                                    // gate simpleToggleMouse would still fire the compact
                                                    // toggle's toggled() when clicks propagate through
                                                    // the expandedLoader (notably during the brief load
                                                    // window before the expanded component's MouseAreas
                                                    // are in the scene graph).
                                                    enabled: !controlPanel.editMode && !expandedOverlay.isExpanded
                                                    pressAndHoldInterval: 300
                                                    Accessible.name: (widgetLoader.item && widgetLoader.item.toggleName) || "Toggle"
                                                    Accessible.role: Accessible.Button
                                                    // ── Click + long-press only ──
                                                    // Page swipes are now tracked by the
                                                    // z:50 DragHandler in pageView (see
                                                    // pageSwipeHandlers). This MA still owns
                                                    // the press for pressAndHoldInterval and
                                                    // the shrink animation, but it no longer
                                                    // tracks the drag — the DragHandler does
                                                    // that without stealing the grab (because
                                                    // preventStealing above keeps this MA's
                                                    // press in its own hands).
                                                    onClicked: {
                                                        // A page swipe composes its press down
                                                        // to this area, so without the guard a
                                                        // drag that ends over this cell would
                                                        // fire toggled() on release.
                                                        if (controlPanel.swallowClick) {
                                                            controlPanel.swallowClick = false;
                                                            return;
                                                        }
                                                        if (widgetLoader.item && widgetLoader.item.toggled)
                                                            widgetLoader.item.toggled();
                                                    }
                                                    onPressAndHold: {
                                                        // A horizontal swipe past the 8 px
                                                        // motion threshold (Handlers) has
                                                        // already claimed the gesture —
                                                        // drop the hold, the user is
                                                        // paging. Also swallow the next
                                                        // click so the underlying control
                                                        // doesn't toggle on release.
                                                        if (controlPanel.swipeArmed
                                                                || controlPanel.swipeWasGesture) {
                                                            controlPanel.swallowClick = true;
                                                            return;
                                                        }
                                                        // NOTE: do NOT check swallowClick here.
                                                        // That flag exists to swallow the next
                                                        // *click* on the cell the user landed
                                                        // on after a swipe, and is cleared in
                                                        // onClicked below. A long-press is a
                                                        // deliberate action — opening the
                                                        // expanded view — and must not be
                                                        // blocked by a stale swallowClick from
                                                        // a previous swipe, otherwise the user
                                                        // would need two holds to open the
                                                        // expanded view after every page swipe.
                                                        if (widgetLoader.item && widgetLoader.item.hasExpandedView) {
                                                            controlPanel.openExpandedView(widgetBg, widgetLoader.item, delegateItem);
                                                        }
                                                    }
                                                }
                                            }

                                            // ── Click absorber: blocks press/click fall-through ──
                                            // When expandedOverlay.isExpanded is true, this MouseArea
                                            // sits between toggleChrome (z = N) and expandedLoader
                                            // (z = N+1) at z=0. Any press that
                                            // expandedOverlay.MouseArea forwards down through
                                            // expandedLoader's empty card-area gaps lands here,
                                            // NOT on the underlying widgetLoader's bgMouseArea /
                                            // Slider press handler.
                                            //
                                            // Forward press events so that inner Flickable drag
                                            // works — without this, the absorber auto-accepts
                                            // the press and the Flickable never sees the drag.
                                            // Absorb click so it doesn't reach MediaWidget.bgMouseArea
                                            // (the bug from the previous fix). Qt auto-accepts
                                            // composed events when there's no handler; an empty
                                            // handler explicitly accepts without re-propagating.
                                            MouseArea {
                                                id: expandedClickAbsorber
                                                enabled: expandedOverlay.isExpanded
                                                anchors.fill: parent
                                                propagateComposedEvents: true
                                                onPressed: (mouse) => { mouse.accepted = false; }
                                                onClicked: (mouse) => { /* absorb */ }
                                                onPressAndHold: (mouse) => { /* absorb */ }
                                            }

                                            // ── Expanded view content (Phase D) ──
                                            // Lives INSIDE widgetBg (same parent as widgetLoader +
                                            // toggleChrome), so the expanded view appears inside
                                            // the morphing widget rather than in a separate
                                            // container. Opacity stays asymmetric on purpose:
                                            // 200ms in (fast arrival) vs the 400ms toggle
                                            // content fade-out (slow absorption), biasing the
                                            // read toward "the expanded view has arrived" while
                                            // the toggle is still bleeding out.
                                            Loader {
                                                id: expandedLoader
                                                anchors.fill: parent
                                                anchors.margins: 24
                                                focus: true
                                                asynchronous: true
                                                // Phase E: only the morph-target cell
                                                // instantiates the expanded view. The gate
                                                // below ensures only the cell whose widgetBg
                                                // matches expandedOverlay.sourceItem loads
                                                // the component; without it, every cell
                                                // would show the expanded view at once.
                                                active: expandedOverlay.sourceItem === widgetBg
                                                sourceComponent: (expandedOverlay.isExpanded && widgetLoader.item) ? widgetLoader.item.expandedComponent : null
                                                opacity: (expandedOverlay.isExpanded && expandedOverlay.sourceItem === widgetBg) ? 1.0 : 0.0
                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 200
                                                    }
                                                }
                                                // Phase G: re-measure the loaded expanded
                                                // component and resize the card if its
                                                // implicitHeight differs from the first-pass
                                                // morph target (expandedHeight). Components
                                                // without implicitHeight (Bluetooth) early-
                                                // return and stay at expandedHeight.
                                                onLoaded: {
                                                    if (expandedOverlay.sourceItem !== widgetBg)
                                                        return;
                                                    let implH = item.implicitHeight || 0;
                                                    if (implH <= 0)
                                                        return;
                                                    // +48 matches expandedLoader's
                                                    // anchors.margins: 24 top + 24 bottom.
                                                    let desired = implH + 48;
                                                    // Use controlPanel.height (870) as the upper bound
                                                    // instead of gridWrapper.height (~320). The card
                                                    // should be able to fill the visible panel, not
                                                    // just the small grid area.
                                                    let maxH = Math.min(controlPanel.height - 40, 680);
                                                    if (maxH > 0)
                                                        desired = Math.min(desired, maxH);
                                                    // Skip the tween if we're already there
                                                    // (e.g. PowerProfile: expandedHeight=320,
                                                    // implH+48=320, no resize needed).
                                                    if (Math.abs(desired - widgetBg.height) < 4)
                                                        return;
                                                    // Flip morphState back to "opening" so the
                                                    // Behavior on height re-enables for the
                                                    // resize tween, recenter, and write the new
                                                    // height. The Qt.callLater below restores
                                                    // the latched "open" state once the tween
                                                    // is in flight.
                                                    widgetBg.morphState = "opening";
                                                    // Center vertically against controlPanel (the
                                                    // visible panel rect), not gridWrapper. Since
                                                    // widgetBg.parent === gridWrapper, subtract
                                                    // gridWrapper's top offset inside controlPanel
                                                    // to get the right y in gridWrapper coords.
                                                    let gridTopInPanel = gridWrapper.mapToItem(controlPanel, 0, 0).y;
                                                    widgetBg.y = (controlPanel.height - desired) / 2 - gridTopInPanel;
                                                    widgetBg.height = desired;
                                                    expandedOverlay.computedTargetHeight = desired;
                                                    Qt.callLater(() => {
                                                        if (widgetBg.morphState === "opening")
                                                            widgetBg.morphState = "open";
                                                    });
                                                }
                                            }
                                        }

                                        EditOverlay {
                                            id: widgetOverlay
                                            parent: gridWrapper
                                            z: 10
                                            x: widgetBg.x
                                            y: widgetBg.y
                                            width: widgetBg.width
                                            height: widgetBg.height
                                            widgetRadius: widgetBg.radius
                                            editMode: controlPanel.editMode
                                            itemIndex: delegateItem.itemIndex
                                            widgetSource: model.source || ""
                                            currentColSpan: model.colSpan
                                            currentRowSpan: model.rowSpan
                                            availableSizes: widgetLoader.item ? widgetLoader.item.availableSizes : undefined
                                            onDragStarted: (grabOffsetX, grabOffsetY) => {
                                                // Position proxy at widgetBg's location in controlPanel coordinates
                                                let pos = widgetBg.mapToItem(controlPanel, 0, 0);
                                                dragProxy.x = pos.x;
                                                dragProxy.y = pos.y;
                                                dragProxy.width = widgetBg.width;
                                                dragProxy.height = widgetBg.height;
                                                dragProxy.radius = widgetBg.radius;
                                                dragProxy.grabOffsetX = grabOffsetX;
                                                dragProxy.grabOffsetY = grabOffsetY;
                                                dragProxy.visible = true;

                                                // Position tracker at widgetBg's center in page-strip coordinates
                                                let fPos = widgetBg.mapToItem(pageView, widgetBg.width / 2, widgetBg.height / 2);
                                                dragTracker.x = fPos.x - 10;
                                                dragTracker.y = fPos.y - 10;
                                                dragTracker.sourceDelegate = delegateItem;

                                                // Ghost the original widget
                                                widgetBg.opacity = 0.3;
                                                controlPanel.dragIndex = delegateItem.itemIndex;
                                            }

                                            onDragMoved: (globalX, globalY) => {
                                                // Update proxy position in controlPanel coordinates
                                                let cp = controlPanel.mapFromItem(null, globalX, globalY);
                                                dragProxy.x = cp.x - dragProxy.grabOffsetX;
                                                dragProxy.y = cp.y - dragProxy.grabOffsetY;

                                                // Update invisible tracker in page-strip coordinates
                                                let fp = pageView.mapFromItem(null, globalX, globalY);
                                                dragTracker.x = fp.x - 10;
                                                dragTracker.y = fp.y - 10;
                                            }

                                            onDragFinished: {
                                                // Hide proxy
                                                dragProxy.visible = false;

                                                // Drop the tracker to trigger DropArea
                                                dragTracker.Drag.drop();
                                                dragTracker.sourceDelegate = null;

                                                // Unghost the widget
                                                widgetBg.opacity = 1.0;
                                                controlPanel.dragIndex = -1;

                                                // Save layout after reorder
                                                controlPanel.saveLayout();
                                            }
                                            onRemoved: {
                                                controlPanel.removeEntry(controlPanel.currentPage, index);
                                            }
                                            onResized: (newColSpan, newRowSpan) => {
                                                controlPanel.resizeEntry(controlPanel.currentPage, index, newColSpan, newRowSpan);
                                            }
                                        }
                                    }
                                } // closes Repeater (cells)
                            } // closes GridLayout
                        } // closes gridWrapper
                    } // closes pageSlot
                    } // closes pageSlots Repeater
                } // closes pageStrip
                // ── Topmost swipe Handlers (z:50) ──
                // TapHandler + DragHandler observe every press in the panel's
                // grid viewport without grabbing the mouse. The cell MAs and
                // slider inner MAs still own the press, so pressAndHold,
                // shrink animation, slider drag, and onClicked all keep
                // working unchanged. The Handlers track the horizontal drag
                // here, including presses that start or end in the inter-cell
                // gap (which the cell MA design could not see).
                Item {
                    id: pageSwipeHandlers
                    anchors.fill: parent
                    z: 50
                    // Handlers are only meaningful when there's more than one
                    // page and we're not in edit mode / expanded view / mid-
                    // rearrange drag.
                    property bool gateActive: controlPanel.pageCount > 1
                        && !controlPanel.editMode
                        && !expandedOverlay.isExpanded
                        && controlPanel.dragIndex === -1
                    // Single DragHandler owns the press lifecycle
                    // (onActiveChanged) and motion (onTranslationChanged).
                    // The previous TapHandler + DragHandler pair had a
                    // race: on a touchpad lift, pressTracker.onPressedChanged
                    // could fire _swipeCommit before swipeTracker became
                    // inactive, and a residual onTranslationChanged would
                    // then overwrite pageStripX with the stale last-drag
                    // value, leaving the strip parked at the lift-off
                    // offset. DragHandler.onTranslationChanged only fires
                    // while the handler is active, so the residual race
                    // is impossible by construction.

                    DragHandler {
                        id: swipeTracker
                        target: null
                        acceptedButtons: Qt.LeftButton
                        // Horizontal-only: disable the y axis so the
                        // translation stays horizontal. Without this,
                        // a vertical drag on a cell would also accumulate
                        // dy and could fight the cell MA's vertical
                        // drag handling.
                        yAxis.enabled: false
                        enabled: pageSwipeHandlers.gateActive

                        // DragHandler does not expose `point` from
                        // onActiveChanged (the live runtime logs
                        // `ReferenceError: point is not defined` if you
                        // try — it is a TapHandler-only hook), and
                        // activeTranslation resets to (0, 0) on release.
                        // Capture the final drag delta here from
                        // onTranslationChanged (the only place active
                        // data is guaranteed to be fresh) and read it
                        // back in onActiveChanged(false) to feed
                        // _swipeCommit. lastDelta is the cumulative
                        // drag distance from the press origin, which
                        // is exactly the value _swipeCommit's
                        // `endX - swipeStartX` expects when swipeStartX
                        // stays at 0.
                        property point lastDelta: Qt.point(0, 0)

                        onActiveChanged: {
                            if (active) {
                                // Press: record the gesture's start state.
                                // swipeStartX/Y stay at 0; the drag
                                // distance (lastDelta.x) is what
                                // _swipeCommit's `endX - swipeStartX`
                                // reduces to.
                                swipeTracker.lastDelta = Qt.point(0, 0);
                                controlPanel.swipeStartStripX = controlPanel.pageStripX;
                                controlPanel.swipeStartTime = Date.now();
                                controlPanel.swipeArmed = false;
                                controlPanel.swipeWasGesture = false;
                                controlPanel.swallowClick = false;
                            } else {
                                // Release: dispatch by whether the gesture
                                // is still eligible. enabledForSwipe()
                                // returns false precisely when something
                                // stole the press mid-gesture
                                // (expandedOverlay opened, panel closed,
                                // edit mode flipped on, a rearrange drag
                                // started) — that is _swipeCancel's job,
                                // not _swipeCommit's.
                                if (controlPanel.swipeArmed
                                        || controlPanel.swipeWasGesture) {
                                    if (controlPanel.enabledForSwipe())
                                        controlPanel._swipeCommit(swipeTracker.lastDelta.x);
                                    else
                                        controlPanel._swipeCancel();
                                }
                                // ALWAYS reset the gesture flags at
                                // end-of-gesture. The press path
                                // (onActiveChanged(true)) only fires when
                                // the next press also has motion — a
                                // static long-press never reaches it, so
                                // these flags would otherwise leak across
                                // gestures and the cell MA's
                                // onPressAndHold would short-circuit on
                                // the "swipeArmed || swipeWasGesture"
                                // guard. swallowClick is intentionally
                                // left alone: it is set by the dispatch
                                // above (and by onPressAndHold during a
                                // swipe) to swallow the next click on the
                                // landed-on cell, and is cleared by the
                                // cell MA.
                                controlPanel.swipeArmed = false;
                                controlPanel.swipeWasGesture = false;
                            }
                        }

                        onTranslationChanged: {
                            // Scoped to active drags — see the block
                            // comment above. onTranslationChanged does
                            // not fire after onActiveChanged(false), so
                            // there is no post-release write to guard.
                            if (!pageSwipeHandlers.gateActive) return;
                            const at = swipeTracker.activeTranslation;
                            if (!at) return;
                            const dx = at.x;
                            const dy = at.y;
                            if (!Number.isFinite(dx) || !Number.isFinite(dy)) return;
                            // Stash the live delta for onActiveChanged
                            // to read on release.
                            swipeTracker.lastDelta = Qt.point(dx, dy);
                            const startX = controlPanel.swipeStartStripX;
                            const maxX = controlPanel.maxPageStripX;
                            if (!Number.isFinite(startX) || !Number.isFinite(maxX)) return;
                            if (!controlPanel.swipeWasGesture
                                    && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
                                controlPanel.swipeWasGesture = true;
                            }
                            if (!controlPanel.swipeArmed
                                    && Math.abs(dx) > 12
                                    && Math.abs(dx) > Math.abs(dy)) {
                                controlPanel.swipeArmed = true;
                                controlPanel.isPageSwiping = true;
                            }
                            if (!controlPanel.swipeArmed) return;
                            // Track the finger 1:1, clamped to the strip's
                            // ends so the first/last page can't be dragged
                            // past the edge, with a little rubber-band
                            // beyond it.
                            let raw = startX + dx;
                            const lo = -maxX;
                            if (raw > 0) raw = raw * 0.35;
                            else if (raw < lo) raw = lo + (raw - lo) * 0.35;
                            controlPanel.pageStripX = raw;
                        }
                    }
                }
                } // closes pageView (grid viewport — indicator and bottom row
                  // are siblings of it, NOT children, so they stay pinned to
                  // the panel while only the strip inside scrolls)

                // ── Page Indicator ──
                // Sits between the grid and the pinned bottom row, in the
                // band the panel's height reserved for it
                // (indicatorBandHeight + gridFooterGap), so there is always
                // visible separation between the last row of toggles and the
                // Edit row below. Hidden while a single page is all there is —
                // no dots to show. In edit mode it also exposes add/remove
                // page controls.
                Item {
                    id: pageIndicator
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: pageView.bottom
                    // No anchors.bottom here: a vertical anchor overrides an
                    // explicit height, which collapsed this band to zero and
                    // pulled the Edit row flush against the dots. The gap below
                    // is controlPanel.gridFooterGap, reserved in the panel's
                    // height — see the band properties on controlPanel.
                    anchors.topMargin: 12
                    width: indicatorRow.implicitWidth
                    height: Math.max(indicatorRow.implicitHeight, 28)
                    visible: controlPanel.pageCount > 1
                    opacity: visible ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutExpo
                        }
                    }

                    Row {
                        id: indicatorRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: controlPanel.pageCount

                            Item {
                                width: 22
                                height: 22
                                // Wider pill for the active page, small dot
                                // for the rest — reads as a position indicator
                                // without needing a number.
                                Rectangle {
                                    id: dot
                                    anchors.centerIn: parent
                                    width: controlPanel.currentPage === index ? 16 : 6
                                    height: 6
                                    radius: 3
                                    color: controlPanel.currentPage === index
                                        ? Qt.rgba(1, 1, 1, 0.9)
                                        : Qt.rgba(1, 1, 1, 0.3)
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 250
                                            easing.type: Easing.OutExpo
                                        }
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 250
                                        }
                                    }
                                }

                                // Tap a dot to jump straight to that page.
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: controlPanel.currentPage !== index
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controlPanel.goToPage(index)
                                }
                            }
                        }
                    }

                    // ── Edit-mode page controls ──
                    // Add sits to the left of the dots, remove to the right.
                    Item {
                        id: addPageButton
                        anchors.right: indicatorRow.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        visible: controlPanel.editMode

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: addPageMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.1)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            sourceSize: Qt.size(14, 14)
                            source: Icons.icon("list-add-symbolic")
                        }
                        MouseArea {
                            id: addPageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanel.addPage()
                        }
                    }

                    Item {
                        id: removePageButton
                        anchors.left: indicatorRow.right
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        // Never offer to remove the only page.
                        visible: controlPanel.editMode && controlPanel.pageCount > 1

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: removePageMouse.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.3) : Qt.rgba(1, 1, 1, 0.1)
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                        Image {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            sourceSize: Qt.size(14, 14)
                            source: Icons.icon("list-remove-symbolic")
                        }
                        MouseArea {
                            id: removePageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: controlPanel.removePage(controlPanel.currentPage)
                        }
                    }
                }


                // ── Bottom Row: Edit + Background Apps Placeholder ──
                // Pinned chrome: anchored to the panel's bottom edge rather
                // than flowing after the grid. This is what frees the full
                // 720px a 4x8 page needs, and keeps Edit reachable without
                // scrolling. (It was a RowLayout inside the old vertical
                // Flickable, so its Layout.* attached properties are gone —
                // sizing is explicit now.)
                Item {
                    id: bottomRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    height: controlPanel.bottomRowHeight
                    // Hide the bottom row while a toggle's expanded view
                    // is open — the morphed card fills the panel and the
                    // edit/bg-apps chrome would otherwise peek through
                    // below it. visible gates input; opacity drives the
                    // Behavior crossfade.
                    opacity: expandedOverlay.isExpanded ? 0.0 : 1.0
                    visible: opacity > 0.01
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutExpo
                        }
                    }

                    // ── Edit button (moved from header) ──
                    // Icon swaps to a tick in edit mode (the click
                    // then becomes "Done" — exit edit mode).
                    // Scale wrapper provides the same shrink-on-tap
                    // animation as the toggle grid cards.
                    MaterialSurface {
                        id: editToggleButton
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 50
                        height: 50
                        radius: 48

                        scale: editToggleMouse.pressed ? 0.95 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }

                        Image {
                            width: 20
                            height: 20
                            anchors.centerIn: parent
                            sourceSize: Qt.size(20, 20)
                            source: controlPanel.editMode
                                ? Icons.icon("checkmark-symbolic")
                                : Icons.icon("document-edit-symbolic")
                        }

                        MouseArea {
                            id: editToggleMouse
                            anchors.fill: parent
                            onClicked: {
                                if (controlPanel.editMode) {
                                    controlPanel.saveLayout();
                                }
                                controlPanel.editMode = !controlPanel.editMode;
                            }
                        }
                    }

                    // ── Background apps placeholder ──
                    // Shows a count of toplevels on the focused workspace
                    // (excluding any floating fullscreen windows), with
                    // up to 2 app-icon thumbnails. Click to open the
                    // task switcher (UIState.switcherOpen).
                    // Scale wrapper provides the same shrink-on-tap
                    // animation as the toggle grid cards.
                    MaterialSurface {
                        id: bgAppsPlaceholder
                        // Pinned right; the old `Item { Layout.fillWidth: true }`
                        // spacer between the two is no longer needed now that
                        // this row is anchored rather than laid out.
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 50
                        width: bgAppsRow.implicitWidth + 30
                        radius: 48

                        scale: bgAppsMouse.pressed ? 0.95 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                       

                        // Hide the placeholder when there are no background
                        // windows (e.g. only the dashboard is open), but
                        // always show it in edit mode so the user can
                        // tap "Add a Control" regardless of workspace state.
                        visible: bgAppsPlaceholder.shouldShow

                        readonly property int bgCount: {
                            const ws = Hyprland.focusedWorkspace;
                            if (!ws) return 0;
                            const tls = ws.toplevels.values;
                            // Count any toplevel — the panel itself lives
                            // on a separate surface and won't appear here.
                            return tls.length;
                        }

                        readonly property bool shouldShow: controlPanel.editMode || bgCount > 0

                        Row {
                            id: bgAppsRow
                            anchors.centerIn: parent
                            spacing: 6

                            // Edit-mode content: plus icon + label.
                            // Contributes to bgAppsRow.implicitWidth so the
                            // outer MaterialSurface resizes itself as the
                            // right pill swaps between the two layouts.
                            Row {
                                spacing: 8
                                visible: controlPanel.editMode
                                Item {
                                    width: 16
                                    height: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    Rectangle {
                                        width: 8
                                        height: 2
                                        radius: 1
                                        color: "white"
                                        anchors.centerIn: parent
                                    }
                                    Rectangle {
                                        width: 2
                                        height: 8
                                        radius: 1
                                        color: "white"
                                        anchors.centerIn: parent
                                    }
                                }
                                Text {
                                    text: "Add a Control"
                                    color: "white"
                                    font.pixelSize: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Normal-mode content: up to 2 app thumbs + count label.
                            // Hidden (not just collapsed) in edit mode so it
                            // doesn't pad bgAppsRow.implicitWidth and make the
                            // pill oversize on the edit-mode swap.
                            Row {
                                spacing: 6
                                visible: !controlPanel.editMode

                                Repeater {
                                    model: {
                                        const ws = Hyprland.focusedWorkspace;
                                        if (!ws) return [];
                                        const tls = ws.toplevels.values;
                                        return tls.slice(0, 2);
                                    }

                                    delegate: Item {
                                        id: bgThumb
                                        width: 22
                                        height: 22

                                        property var ipc: modelData ? modelData.lastIpcObject : null
                                        property string appIcon: {
                                            let identifiers = [];
                                            let ipc = bgThumb.ipc;
                                            if (ipc) {
                                                if (ipc.class) identifiers.push(ipc.class);
                                                if (ipc.initialClass) identifiers.push(ipc.initialClass);
                                            }
                                            let wcls = (modelData ? (modelData.initialClass || modelData.appId || (modelData.wayland ? modelData.wayland.appId : "") || "") : "");
                                            if (wcls) identifiers.push(wcls);

                                            for (let id of identifiers) {
                                                let entry = DesktopEntries.heuristicLookup(id);
                                                if (entry && entry.icon)
                                                    return (entry.icon.startsWith("/") ? "file://" + entry.icon : "image://icon/" + entry.icon);
                                            }

                                            let appId = (modelData ? (modelData.appId || modelData.initialClass || "") : "");
                                            return appId !== "" ? "image://icon/" + appId : "";
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: width / 2
                                            color: Qt.rgba(1, 1, 1, 0.12)
                                            border.color: Qt.rgba(1, 1, 1, 0.18)
                                            border.width: 1
                                        }
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            source: bgThumb.appIcon
                                            sourceSize: Qt.size(22, 22)
                                            fillMode: Image.PreserveAspectFit
                                            visible: bgThumb.appIcon !== ""
                                        }
                                    }
                                }

                                Text {
                                    text: bgAppsPlaceholder.bgCount + (bgAppsPlaceholder.bgCount === 1 ? " app" : " apps") + " in background"
                                    color: Qt.rgba(1, 1, 1, 0.7)
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        MouseArea {
                            id: bgAppsMouse
                            anchors.fill: parent
                            onClicked: {
                                if (controlPanel.editMode) {
                                    // Toggle: tapping the Add-a-control
                                    // pill again closes the popup.
                                    if (addControlPopup.opacity > 0)
                                        addControlPopup.close();
                                    else
                                        addControlPopup.open();
                                } else {
                                    UIState.switcherOpen = !UIState.switcherOpen;
                                }
                            }
                        }
                    }
                }
            } // closes background Rectangle

            // ── Add Control Popup ──
            FolderListModel {
                id: togglesFolderModel
                folder: Qt.resolvedUrl("toggles")
                nameFilters: ["*.qml"]
                showDirs: false
            }

            // ── Expanded View Overlay (Phase D slimmed) ──
            // Only two responsibilities remain:
            //   1. Click-to-close backdrop (this Item itself, full-overlay,
            //      with a MouseArea that catches outside-click to close).
            //   2. State owner: isExpanded, deferred-open slot, per-open
            //      geometry parameters (startX/Y/Width/Height,
            //      computedTargetHeight), and open()/close() that drive
            //      the morph on `sourceItem` (which is now widgetBg itself,
            //      reparented into gridWrapper since Phase B).
            //
            // No morph container lives here anymore. expandedCard is gone;
            // expandedLoader lives inside widgetBg.
            Item {
                id: expandedOverlay
                anchors.fill: parent
                // Visible only during open/close animation — otherwise
                // it blocks clicks on the toggle grid below.
                // The inner MouseArea stays interactive throughout because
                // we animate overlayFadeBg.opacity, not this Item's own opacity.
                visible: isExpanded
                z: 200

                property var sourceItem: null
                property var widgetItem: null
                // Deferred-open slot: if openExpandedView() is called while
                // qs.morphComplete is false (e.g. user presses-and-holds a
                // toggle in the same gesture that opens the panel), we stash
                // the args here and replay them once the panel bloom settles.
                property var pendingSourceRect: null
                property var pendingWidgetItem: null
                property var pendingDelegateItemRef: null
                property bool hasPendingOpen: false
                // Source widget's natural radius captured at open() time.
                // Used by close() to animate back to the source's actual
                // shape without depending on the live (animated) width/
                // height values, which would drift during the morph.
                // Phase H: removed — captured per-toggle on widgetBg.sourceRadius
                // (see Edit 2). The shared property got overwritten on every
                // subsequent open, causing the radius cross-talk bug.
                // Target height computed once per open() — replaces the
                // previous Qt.binding() chain that re-evaluated on every
                // geometry change and produced visible first-frame jumps.
                property real computedTargetHeight: 0
                property bool isExpanded: false
                // Captured at open() time so the morphCompleteTimer
                // (declared outside the Repeater delegate) can restore
                // the cell-bound geometry bindings on the morphed
                // widgetBg after the close animation. Without this,
                // the Timer's onTriggered can't reference `delegateItem`
                // because it lives outside the Repeater's scope.
                property var delegateItemRef: null
                // Set to true by open() when the expanded view opens from
                // a long-press. The expanded overlay's click-absorber MA
                // uses this to ignore the release of that long-press (the
                // finger is at the original cell position, which is now
                // outside the morphed card; without this guard the
                // release is misread as an out-of-card click and dismisses
                // the view the user just opened). Cleared by onClicked
                // after consuming that first click, and by close() as a
                // safety net.
                property bool pressOpenedExpanded: false

                Behavior on opacity {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutExpo
                    }
                }

                // Drive the morph on `sourceItem` (widgetBg itself). The
                // geometry Behaviors on widgetBg (gated on isMorphing)
                // animate the geometry changes written here.
                function open() {
                    // Mark this open as triggered by a long-press so the
                    // click-absorber MA ignores the release of that press
                    // (the finger is at the original cell position, which
                    // is now outside the morphed card; without this guard
                    // the release is misread as an out-of-card click and
                    // dismisses the view the user just opened). Cleared
                    // by onClicked after consuming that first click.
                    expandedOverlay.pressOpenedExpanded = true;
                    isExpanded = true;
                    // (visible: isExpanded is a binding on the parent
                    // Item, so setting isExpanded = true already drives
                    // visible. No imperative visible = true needed here —
                    // it would break the binding and leave the overlay
                    // stuck visible after the next close().)
                    // Drive the background fade Rectangle (not this Item's
                    // own opacity, which was previously used for visibility
                    // but would disable the inner MouseArea during animation).
                    overlayFadeBg.opacity = 1.0;

                    // Resolve the expanded component (already lives inside
                    // widgetBg now, so no sourceComponent assignment is
                    // needed here — expandedLoader reads widgetItem directly
                    // via its binding). Phase G: first-pass target uses
                    // expandedHeight (a fixed per-toggle property) so the
                    // morph has a stable target. expandedLoader.onLoaded
                    // re-measures the loaded component's implicitHeight and
                    // tweens to that size if it differs from expandedHeight.
                    // Dropped the previous `w.implicitHeight` branch — it
                    // always read 0 because `w` is the toggle widget root
                    // (an Item with no implicitHeight), not the expanded
                    // component.
                    let w = widgetItem;
                    let explicitH = (w && w.expandedHeight > 0) ? w.expandedHeight : 0;
                    let targetH = explicitH > 0 ? explicitH : 420;

                    // Use controlPanel.height (870) instead of gridWrapper.height
                    // (~320) so the expanded card can fill the visible panel.
                    let maxH = Math.min(controlPanel.height - 40, 680);
                    if (maxH > 0) {
                        targetH = Math.min(targetH, maxH);
                    }
                    expandedOverlay.computedTargetHeight = targetH;

                    // Drive the actual toggle's geometry morph. Use
                    // gridWrapper bounds (the parent of widgetBg) so the
                    // morphed card doesn't overflow the Flickable's 24px
                    // left/right margins. Phase D used expandedOverlay.width
                    // (= controlPanel.width = 400) which overflowed
                    // gridWrapper (= 352) by 48px and rendered past the
                    // panel's right edge.
                    if (sourceItem) {
                        sourceItem.morphState = "opening";
                        // Phase G2: break the radius binding FIRST. The
                        // radius binding (Math.min(width, height) / 2 for
                        // 1x1 cells) captures width and height as
                        // dependencies; if width/height are assigned before
                        // the binding is broken, the binding re-evaluates
                        // synchronously and writes a transient large radius
                        // (e.g. 176 for 352x480). The Behavior on radius
                        // then animates from that transient value toward 16
                        // instead of from the natural 55, so the corner
                        // rounding visibly lags behind the geometry morph.
                        sourceItem.radius = 16;
                        sourceItem.x = 0;
                        // Center vertically against controlPanel (the visible
                        // panel rect, 870 px tall), not gridWrapper.
                        // Since sourceItem.parent === gridWrapper (the grid is
                        // a Repeater child now, so its id is not in scope
                        // here), subtract the parent's top offset inside
                        // controlPanel to get the right y in gridWrapper coords.
                        const grid = sourceItem.parent;
                        let gridTopInPanel = grid.mapToItem(controlPanel, 0, 0).y;
                        sourceItem.y = (controlPanel.height - targetH) / 2 - gridTopInPanel;
                        sourceItem.width = grid.width;
                        sourceItem.height = targetH;
                        // Cancel any residual press-scale so the morph
                        // geometry isn't composed with a 0.95 scale.
                        sourceItem.scale = 1.0;
                    }

                    // After the open morph lands, latch into "open" so any
                    // minor geometry tweaks don't re-trigger Behaviors.
                    Qt.callLater(() => {
                        if (sourceItem && sourceItem.morphState === "opening")
                            sourceItem.morphState = "open";
                    });
                }

                function close() {
                    // Safety net: clear the long-press-guard flag so a
                    // later open from a different path starts clean.
                    expandedOverlay.pressOpenedExpanded = false;
                    // Phase F: write geometry BEFORE flipping isExpanded.
                    // With isMorphing now gated on morphState (not on
                    // isExpanded), the Behavior fires on these assignments
                    // regardless of isExpanded. Driving the geometry first
                    // lets the 400ms OutExpo shrink run, while the
                    // isExpanded flip below triggers the content fade-in
                    // (400ms) and expandedLoader fade-out (200ms) in
                    // parallel.
                    if (sourceItem) {
                        sourceItem.morphState = "closing";
                        // Phase K: hoist del capture above the radius
                        // block so the natural radius can be computed
                        // from the same delegate dimensions the
                        // geometry writes below use. Without the
                        // natural radius here, the radiusAnim lands on
                        // a hardcoded value and the binding restore
                        // snaps to the cell's real natural radius
                        // 400 ms later — the visible corner-rounding
                        // jump.
                        let del = expandedOverlay.delegateItemRef;
                        // Phase K: derive the natural radius from the
                        // captured del, not a hardcoded literal. The
                        // cell-bound formula matches the binding that
                        // morphCompleteTimer restores 400 ms later:
                        //   (colSpan >= 2 && rowSpan >= 2)
                        //     ? 16
                        //     : Math.min(width, height) / 2
                        // so the radiusAnim lands on exactly the value
                        // the binding would produce — no end-of-morph
                        // snap.
                        //
                        // fallback: if del is missing (delegate
                        // destroyed mid-morph), use 16. Same default the
                        // restored binding uses for the no-del case.
                        let naturalRadius = del
                            ? ((del.colSpan >= 2 && del.rowSpan >= 2)
                                ? 16
                                : Math.min(del.width, del.height) / 2)
                            : 16;
                        // Phase G3: drive the close corner-rounding
                        // animation with an explicit NumberAnimation.
                        // The Behavior on radius may not fire reliably
                        // on the first assignment after morphState flips
                        // (state-machine batching at the same event
                        // boundary can swallow the change in some Qt
                        // versions), so we drive the animation
                        // directly. The static sourceItem.radius write
                        // below stays as a fallback: either the
                        // animation lands or the static value renders.
                        // Create + assign target in one go. Property
                        // name keys in the createObject() literal must
                        // not be QML reserved words; `target` is fine,
                        // `property` is not. So we pass target here and
                        // assign `property`/to/duration/easing via
                        // bracket access below.
                        let radiusAnim = numberAnimationComponent.createObject(sourceItem, {
                            target: sourceItem
                        });
                        if (radiusAnim) {
                            radiusAnim["property"] = "radius";
                            // Phase K: animate to the cell's natural
                            // radius, not a literal. Phase I left the
                            // literal 24 in place when it removed
                            // sourceRadius, so every close-path radius
                            // animation landed on 24 and then the
                            // binding restore snapped to the real
                            // natural value 0–1 frame later.
                            radiusAnim.to = naturalRadius;
                            radiusAnim.duration = 400;
                            radiusAnim.easing.type = Easing.OutExpo;
                            radiusAnim.start();
                            // Explicit cleanup: morphCompleteTimer
                            // releases sourceItem and the radius binding
                            // restores, but the dynamic animation object
                            // itself would otherwise linger until the
                            // delegate is destroyed. .finished fires on
                            // the animation's natural completion.
                            radiusAnim.finished.connect(() => radiusAnim.destroy());
                        }
                        // Phase G2: keep radius BEFORE width/height for
                        // symmetry with open(). The radius binding is
                        // already broken from open() (only restored by
                        // morphCompleteTimer 400ms after close() lands),
                        // so close() should already work — but keeping
                        // the same order makes the code robust against
                        // any future change that restores the binding
                        // earlier. Phase K: use naturalRadius (matches
                        // radiusAnim.to above) so both writes land on
                        // the same value — no end-of-morph snap.
                        sourceItem.radius = naturalRadius;
                        // Drive the close animation's target geometry from the live
                        // delegateItemRef bounds. Reading them at close time (not
                        // from the captured start* values from open time) guarantees
                        // the close animation lands on the same value the
                        // morphCompleteTimer binding restore will produce — no
                        // end-of-close snap when the cell bound has shifted
                        // during the expanded view.
                        sourceItem.x      = del ? del.x      : sourceItem.x;
                        sourceItem.y      = del ? del.y      : sourceItem.y;
                        sourceItem.width  = del ? del.width  : sourceItem.width;
                        sourceItem.height = del ? del.height : sourceItem.height;
                    }

                    isExpanded = false;
                    // Fade out the visual layer (not this Item's opacity,
                    // which must stay visible to keep the inner MouseArea
                    // interactive during the animation).
                    overlayFadeBg.opacity = 0;
                    // visible: isExpanded binding drives visible to false
                    // here. The 400ms close morph animates the geometry
                    // of sourceItem (now reparented into gridWrapper), and
                    // sourceItem's own Behavior on opacity (gated on
                    // morphState === "closing") fades it out in parallel.
                    // No imperative visible = false needed.

                    // After the close morph lands, snap the widgetBg
                    // geometry bindings back to the cell-bound form. Using
                    // Qt.binding() restores the original conditional
                    // bindings (lines ~1563-1565) so the toggle reappears
                    // with its natural radius (auto-computed from cell
                    // size for 1x1 circles, fixed 16 for 2x2+).
                    morphCompleteTimer.restart();
                }

                // Phase G3 hotfix: factory for the deterministic
                // close-radius NumberAnimation. Earlier this declared
                // `target: sourceItem` in the NumberAnimation body,
                // but sourceItem is a property on the grandparent
                // expandedOverlay, not a QML id in the new object's
                // scope chain — QML's JS resolver returned a
                // ReferenceError at load time, the Component
                // instantiation silently failed, and createObject()
                // returned null in close(). Hence no animation.
                // Fix: leave target unset in the factory; pass it
                // imperatively from close() via
                // createObject(sourceItem, { target: sourceItem }).
                Component {
                    id: numberAnimationComponent
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutExpo
                    }
                }

                // Restore the cell-bound geometry bindings on the morphed
                // widgetBg once the close animation has finished.
                // Reads dimension values from expandedOverlay.delegateItemRef
                // (the Repeater delegate) and expands them into
                // bindings via Qt.binding(), since this Timer runs in
                // expandedOverlay scope and doesn't have direct access
                // to either `delegateItem` or `model`.
                Timer {
                    id: morphCompleteTimer
                    interval: 400
                    repeat: false
                    onTriggered: {
                        let s = expandedOverlay.sourceItem;
                        if (!s || s.morphState !== "closing")
                            return;
                        let del = expandedOverlay.delegateItemRef;
                        s.morphState = "idle";
                        s.x = Qt.binding(function() { return del ? del.x : 0; });
                        s.y = Qt.binding(function() { return del ? del.y : 0; });
                        s.width = Qt.binding(function() { return del ? del.width : 0; });
                        s.height = Qt.binding(function() { return del ? del.height : 0; });
                        // Phase I: restore the LIVE cell-bound formula, reading colSpan/
                        // rowSpan from delegateItemRef (the captured Repeater delegate)
                        // and width/height from the same. Edit 1 declares colSpan/rowSpan
                        // as real QML properties on delegateItem so they're accessible
                        // from morphCompleteTimer's expandedOverlay scope (where `model`
                        // is not resolvable).
                        //
                        // This binding now tracks resize: when the user changes the
                        // toggle's shape in edit mode via the ResizeHandle, model.colSpan
                        // and model.rowSpan update, delegateItem's declared properties
                        // follow (Edit 1), and this binding re-evaluates against the new
                        // shape's formula. The Behavior on radius (file-scope, gated on
                        // controlPanel.editMode) animates the radius change.
                        //
                        // Per-toggle isolation is preserved: each restored binding reads
                        // `del` (its own delegateItemRef, captured at open time via
                        // expandedOverlay.delegateItemRef = delegateRef). Other toggles'
                        // bindings read their own `del` — no cross-toggle interference
                        // (the original Phase H bug).
                        s.radius = Qt.binding(function() {
                            if (!del) return 16;
                            return (del.colSpan >= 2 && del.rowSpan >= 2)
                                ? 16
                                : Math.min(del.width, del.height) / 2;
                        });
                        // Phase G3: restore scale binding too, so press-scale
                        // animation works again on toggles that have
                        // hasExpandedView (network, bluetooth, power profile,
                        // screen record, media). Without this,
                        // sourceItem.scale = 1.0 in open() permanently breaks
                        // the binding and subsequent presses can never
                        // animate the 1.0 -> 0.95 -> 1.0 shrink.
                        s.scale = Qt.binding(function() {
                            // Phase G3 hotfix: use s.dragOverlay /
                            // s.isItemPressed instead of the bare
                            // widgetOverlay / isItemPressed ids. The
                            // bare ids are Repeater-child ids and not
                            // hoisted into expandedOverlay's scope, so
                            // the original binding threw ReferenceError
                            // when re-evaluated. Re-binding through
                            // `s` (a captured local = widgetBg) goes
                            // through widgetBg.dragOverlay / isItemPressed
                            // properties, which always resolve.
                            return s.dragOverlay.dragActive
                                ? 1.05
                                : (s.isItemPressed ? 0.95 : 1.0);
                        });
                        expandedOverlay.delegateItemRef = null;
                        // (visible: isExpanded is a binding; close() sets
                        // isExpanded = false which immediately drives
                        // visible to false. No imperative write needed.)
                    }
                }

                // Replay a deferred open() once the panel's bloom-scale
                // spring has settled. Watches qs.morphComplete (set by
                // onSmoothMorphProgressChanged when smoothMorphProgress
                // reaches 1.0).
                Connections {
                    target: qs
                    function onMorphCompleteChanged() {
                        // Phase G3: scope-qualify. replayPendingOpen
                        // lives on controlPanel (defined at :1264), not
                        // on expandedOverlay, so the unqualified call
                        // throws ReferenceError and the deferred open
                        // is silently dropped.
                        if (qs.morphComplete)
                            controlPanel.replayPendingOpen();
                    }
                }

                // ── Visual fade layer (does NOT affect hit-testing) ──
                // Fades from 1→0 over 400ms during close(), keeping
                // the inner MouseArea interactive throughout the animation.
                // Without this, Qt disables MouseArea hit-testing when
                // the overlay's own opacity reaches 0, letting clicks
                // slip through to complexHoldArea/MediaWidget below.
                Rectangle {
                    id: overlayFadeBg
                    anchors.fill: parent
                    // Dark semi-transparent backdrop for the expanded view.
                    // Not bgSurface.color (Frosted Glass = rgba(255,255,255,0.1))
                    // which produces a white-wash over the expanded card.
                    color: Qt.rgba(0, 0, 0, 0)
                    opacity: 0
                    Behavior on opacity {
                        enabled: !controlPanel.editMode
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutExpo
                        }
                    }
                }

                MouseArea {
                    // Phase G2: forward in-card clicks to inner MouseAreas
                    // (ExpandedHeader switch, MediaWidget play controls,
                    // BrightnessSlider track, network rows, etc.) by
                    // enabling composed-event propagation and rejecting
                    // in-card clicks in both onPressed AND onClicked.
                    //
                    // Without propagateComposedEvents: true, the composed
                    // `clicked` event is auto-accepted by THIS MouseArea
                    // (Qt default for composed events), so even though the
                    // press propagates via mouse.accepted = false in
                    // onPressed, the click does NOT reach inner MouseAreas.
                    // Result: every click inside the morphed card is
                    // swallowed here, inner controls never see the click,
                    // and the entire expandedUI feels click-through.
                    //
                    // Per Qt docs: composed events (clicked, pressAndHold)
                    // require propagateComposedEvents: true to be forwarded.
                    // With it on, setting mouse.accepted = false in
                    // onClicked causes the click to propagate down the
                    // stacking order to the next MouseArea beneath us
                    // (i.e. expandedLoader.item's inner controls).
                    //
                    // Why pressAndHold doesn't need explicit rejection:
                    // this MouseArea has no onPressAndHold handler, so
                    // Qt's default (don't auto-accept composed events
                    // when there's no handler) lets pressAndHold pass
                    // through naturally once propagateComposedEvents is
                    // enabled. We don't need the complexHoldArea guard
                    // we had before — complexHoldArea.enabled now also
                    // checks !expandedOverlay.isExpanded so it doesn't
                    // reactivate during the expanded state.
                    //
                    // Out-of-card clicks: do nothing in onPressed and
                    // let auto-accept consume the click, then call
                    // close() in onClicked.
                    enabled: expandedOverlay.isExpanded
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    propagateComposedEvents: true
                    onPressed: (mouse) => {
                        let s = expandedOverlay.sourceItem;
                        if (!s)
                            return;
                        let p = expandedOverlay.mapToItem(s, mouse.x, mouse.y);
                        let inside = p.x >= 0 && p.x < s.width
                                  && p.y >= 0 && p.y < s.height;
                        if (inside)
                            mouse.accepted = false;  // forward to inner MouseAreas
                        else
                            mouse.accepted = true;  // explicitly consume (dismiss click)
                    }
                    onClicked: (mouse) => {
                        // Ignore the release of the long-press that
                        // opened this view. The finger is at the original
                        // cell position, which is now outside the morphed
                        // card; without this guard the release is misread
                        // as an out-of-card click and dismisses the view
                        // the user just opened. Clear the flag here so
                        // real clicks after this release (e.g. tapping
                        // outside to dismiss) are handled normally.
                        if (expandedOverlay.pressOpenedExpanded) {
                            expandedOverlay.pressOpenedExpanded = false;
                            mouse.accepted = true;  // consume, don't propagate
                            return;
                        }
                        let s = expandedOverlay.sourceItem;
                        if (!s) {
                            expandedOverlay.close();
                            return;
                        }
                        let p = expandedOverlay.mapToItem(s, mouse.x, mouse.y);
                        let inside = p.x >= 0 && p.x < s.width
                                  && p.y >= 0 && p.y < s.height;
                        if (inside) {
                            // Forward the composed click event down to the
                            // expandedLoader's inner MouseAreas. Without
                            // this, propagateComposedEvents: true has no
                            // effect — Qt only forwards when the receiver
                            // explicitly rejects the composed event.
                            mouse.accepted = false;
                        } else {
                            // Out-of-card click: dismiss the expanded view.
                            // mouse.accepted stays true (auto-accepted by
                            // the composed-events machinery) — no
                            // propagation needed.
                            expandedOverlay.close();
                        }
                    }
                }
            }
        } // closes controlPanel

        // ── Add Control Popup (sibling of controlPanel, anchored to its left) ──
        Rectangle {
            id: addControlPopup
            // Closed: tucked against controlPanel's left edge. Open: slid out 16px to the left.
            x: controlPanel.x - width - (opacity > 0 ? 16 : 0)
            y: controlPanel.y
            width: 400
            height: controlPanel.height
            radius: 18
            color: "transparent"
            visible: opacity > 0
            opacity: 0
            // Match the controlPanel's bloom scale so the popup shrinks/expands together
            // with the rest of the panel container.
            scale: panelContainer.bloomScale
            transformOrigin: Item.TopRight

            MaterialSurface {
                anchors.fill: parent
                radius: parent.radius
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }
            Behavior on x {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutExpo
                }
            }

            // Click outside the popup (on the popup's own transparent rect,
            // not panelContainer) to close. z is below the inner ColumnLayout
            // so clicks inside the popup content still hit it.
            MouseArea {
                anchors.fill: parent
                z: -1
                enabled: addControlPopup.opacity > 0.5
                onClicked: addControlPopup.close()
            }

            function open() {
                opacity = 1.0;
            }
            function close() {
                opacity = 0.0;
            }

            // Preview metrics — matches the real grid math. Bound to the same
            // controlPanel properties the real grid uses so the preview can't
            // drift from what actually gets inserted.
            readonly property real realCellSize: controlPanel.cellSize
            readonly property real realGridSpacing: controlPanel.gridSpacing
            readonly property real pvScale: 1

            function realW(cs) {
                return cs * realCellSize + (cs - 1) * realGridSpacing;
            }
            function realH(rs) {
                return rs * realCellSize + (rs - 1) * realGridSpacing;
            }
            function pvW(cs) {
                return realW(cs) * pvScale;
            }
            function pvH(rs) {
                return realH(rs) * pvScale;
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // ── Header ──
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Add a Control"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.1)
                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            sourceSize: Qt.size(24, 24)
                            source: Icons.icon("window-close-symbolic")
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: addControlPopup.close()
                        }
                    }
                }

                // ── Scrollable toggle sections ──
                Flickable {
                    id: addControlFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: addSectionsColumn.implicitHeight
                    ScrollBar.vertical: ScrollBar {}

                    ColumnLayout {
                        id: addSectionsColumn
                        width: addControlFlickable.width
                        spacing: 24

                        Repeater {
                            model: togglesFolderModel

                            delegate: ColumnLayout {
                                id: toggleSection
                                Layout.fillWidth: true
                                spacing: 10

                                // Hide this section until the inspector confirms isControlWidget
                                visible: !!(sectionInspector.item && sectionInspector.item.isControlWidget)
                                Layout.preferredHeight: visible ? implicitHeight : 0

                                property string toggleSource: "toggles/" + model.fileName

                                // Inspector — loads once to read toggle properties
                                Loader {
                                    id: sectionInspector
                                    source: Qt.resolvedUrl(toggleSection.toggleSource)
                                    asynchronous: true
                                    visible: false
                                    property var modelData: ({
                                            colSpan: 2,
                                            rowSpan: 1
                                        })
                                }

                                property bool isSimple: !!(sectionInspector.item && sectionInspector.item.isSimpleToggle)

                                property var sizes: {
                                    if (!sectionInspector.item)
                                        return [
                                            {
                                                colSpan: 1,
                                                rowSpan: 1
                                            }
                                        ];
                                    let item = sectionInspector.item;
                                    if (item.availableSizes && Array.isArray(item.availableSizes) && item.availableSizes.length > 0)
                                        return item.availableSizes;
                                    if (item.isSimpleToggle)
                                        return [
                                            {
                                                colSpan: 1,
                                                rowSpan: 1
                                            },
                                            {
                                                colSpan: 2,
                                                rowSpan: 1
                                            },
                                            {
                                                colSpan: 2,
                                                rowSpan: 2
                                            }
                                        ];
                                    return [
                                        {
                                            colSpan: 2,
                                            rowSpan: 1
                                        }
                                    ];
                                }

                                property string sectionName: {
                                    if (sectionInspector.item)
                                        return sectionInspector.item.toggleName || sectionInspector.item.titleText || model.fileName.replace(".qml", "");
                                    return model.fileName.replace(".qml", "");
                                }

                                // ── Section header ──
                                Text {
                                    text: toggleSection.sectionName
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 13
                                    font.bold: true
                                    font.letterSpacing: 0.5
                                    Layout.fillWidth: true
                                }

                                // ── Size previews in a horizontal flow ──
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Repeater {
                                        model: toggleSection.sizes

                                        delegate: ColumnLayout {
                                            spacing: 6

                                            property int pColSpan: modelData.colSpan
                                            property int pRowSpan: modelData.rowSpan
                                            property real pW: addControlPopup.pvW(pColSpan)
                                            property real pH: addControlPopup.pvH(pRowSpan)
                                            property real rW: addControlPopup.realW(pColSpan)
                                            property real rH: addControlPopup.realH(pRowSpan)
                                            property real sc: addControlPopup.pvScale

                                            // ── Preview cell ──
                                            Item {
                                                Layout.preferredWidth: pW
                                                Layout.preferredHeight: pH
                                                clip: true

                                                // Scale wrapper — renders at real grid size, scaled down
                                                Item {
                                                    width: rW
                                                    height: rH
                                                    scale: sc
                                                    transformOrigin: Item.TopLeft

                                                    Rectangle {
                                                        id: pvBg
                                                        anchors.fill: parent
                                                        property bool isCircle: pColSpan === 1 && pRowSpan === 1
                                                        radius: isCircle ? Math.min(width, height) / 2 : ((pColSpan >= 2 && pRowSpan >= 2) ? 24 : Math.min(width, height) / 2)
                                                        color: "transparent"
                                                        clip: true

                                                        layer.enabled: qs.isOpen || qs.dragOffset > 0
                                                        layer.effect: OpacityMask {
                                                            maskSource: Rectangle {
                                                                width: pvBg.width
                                                                height: pvBg.height
                                                                radius: pvBg.radius
                                                            }
                                                        }

                                                        // Cell background — matches the control center's bgSurface
                                                        // so the preview is visually identical to the real cell.
                                                        MaterialSurface {
                                                            id: pvCellSurface
                                                            anchors.fill: parent
                                                            radius: pvBg.radius
                                                        }

                                                        // Toggle content loader
                                                        Loader {
                                                            id: pvLoader
                                                            anchors.fill: parent
                                                            property var modelData: ({
                                                                    colSpan: pColSpan,
                                                                    rowSpan: pRowSpan
                                                                })
                                                            source: toggleSection.toggleSource
                                                            asynchronous: true
                                                        }

                                                        // ── Shell chrome for simple toggles ──
                                                        // Mirrors controlPanel's toggleChrome: transparent
                                                        // wrapper that hosts the inner icon circle and text.
                                                        Item {
                                                            id: pvChrome
                                                            anchors.fill: parent
                                                            visible: pvLoader.item && pvLoader.item.isSimpleToggle === true

                                                            // ── Layout for non-2x2 toggles (1x1 circles, 2x1 pills) ──
                                                            GridLayout {
                                                                visible: !(pColSpan === 2 && pRowSpan === 2)
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                x: 14
                                                                width: parent.width - x - 14

                                                                columns: pColSpan > pRowSpan ? 2 : 1
                                                                rowSpacing: 8
                                                                columnSpacing: 12

                                                                Rectangle {
                                                                    Layout.alignment: Qt.AlignCenter
                                                                    width: (pColSpan > 1) ? 48 : 24
                                                                    height: (pColSpan > 1) ? 48 : 24
                                                                    radius: width / 2
                                                                    color: "transparent"

                                                                    MaterialSurface {
                                                                        id: pvInnerSurface
                                                                        anchors.fill: parent
                                                                        radius: parent.radius
                                                                        visible: pColSpan > 1
                                                                        isToggleCircle: true
                                                                        isActive: pvLoader.item ? !!pvLoader.item.isActive : false
                                                                        accentColor: (pvLoader.item && pvLoader.item.activeColor) ? pvLoader.item.activeColor : (Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
                                                                    }

                                                                    Item {
                                                                        anchors.centerIn: parent
                                                                        width: 28
                                                                        height: 28

                                                                        Image {
                                                                            id: pvChromeIcon
                                                                            anchors.fill: parent
                                                                            sourceSize: Qt.size(28, 28)
                                                                            source: (pvLoader.item && pvLoader.item.iconSource) || ""
                                                                            visible: false
                                                                        }
                                                                        ColorOverlay {
                                                                            anchors.fill: pvChromeIcon
                                                                            source: pvChromeIcon
                                                                            color: pColSpan > 1 ? pvInnerSurface.iconColor : pvCellSurface.iconColor
                                                                        }
                                                                    }
                                                                }

                                                                ColumnLayout {
                                                                    visible: pColSpan > 1
                                                                    Layout.alignment: pColSpan > pRowSpan ? Qt.AlignVCenter | Qt.AlignLeft : Qt.AlignHCenter
                                                                    Layout.fillWidth: pColSpan > pRowSpan
                                                                    spacing: 0

                                                                    Text {
                                                                        text: (pvLoader.item && (pvLoader.item.titleText !== undefined ? pvLoader.item.titleText : pvLoader.item.toggleName)) || ""
                                                                        color: pvCellSurface.fgColor
                                                                        font.pixelSize: 14
                                                                        font.bold: true
                                                                        Layout.fillWidth: true
                                                                        horizontalAlignment: pColSpan > pRowSpan ? Text.AlignLeft : Text.AlignHCenter
                                                                        elide: Text.ElideRight
                                                                    }

                                                                    Text {
                                                                        text: (pvLoader.item && pvLoader.item.subtitleText) || ""
                                                                        visible: text !== ""
                                                                        color: pvCellSurface.fgColor
                                                                        font.pixelSize: 13
                                                                        font.bold: true
                                                                        Layout.fillWidth: true
                                                                        horizontalAlignment: pColSpan > pRowSpan ? Text.AlignLeft : Text.AlignHCenter
                                                                        elide: Text.ElideRight
                                                                    }
                                                                }
                                                            }

                                                            // ── Layout for 2x2 toggles ──
                                                            Item {
                                                                anchors.fill: parent
                                                                visible: pColSpan === 2 && pRowSpan === 2

                                                                Rectangle {
                                                                    id: pvToggleCircle
                                                                    width: 48
                                                                    height: 48
                                                                    radius: 24
                                                                    anchors.top: parent.top
                                                                    anchors.topMargin: 16
                                                                    anchors.left: parent.left
                                                                    anchors.leftMargin: 16
                                                                    color: "transparent"

                                                                    MaterialSurface {
                                                                        id: pvCircleSurface
                                                                        anchors.fill: parent
                                                                        radius: parent.radius
                                                                        isToggleCircle: true
                                                                        isActive: pvLoader.item ? !!pvLoader.item.isActive : false
                                                                        accentColor: (pvLoader.item && pvLoader.item.activeColor) ? pvLoader.item.activeColor : (Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
                                                                    }

                                                                    Item {
                                                                        anchors.centerIn: parent
                                                                        width: 28
                                                                        height: 28

                                                                        Image {
                                                                            id: pvCircleIcon
                                                                            anchors.fill: parent
                                                                            sourceSize: Qt.size(28, 28)
                                                                            source: (pvLoader.item && pvLoader.item.iconSource) || ""
                                                                            visible: false
                                                                        }
                                                                        ColorOverlay {
                                                                            anchors.fill: pvCircleIcon
                                                                            source: pvCircleIcon
                                                                            color: pvCircleSurface.iconColor
                                                                        }
                                                                    }
                                                                }

                                                                ColumnLayout {
                                                                    anchors.bottom: parent.bottom
                                                                    anchors.bottomMargin: 16
                                                                    anchors.left: parent.left
                                                                    anchors.leftMargin: 16
                                                                    anchors.right: parent.right
                                                                    anchors.rightMargin: 16
                                                                    spacing: 0

                                                                    Text {
                                                                        text: (pvLoader.item && (pvLoader.item.titleText !== undefined ? pvLoader.item.titleText : pvLoader.item.toggleName)) || ""
                                                                        color: pvCellSurface.fgColor
                                                                        font.pixelSize: 14
                                                                        font.bold: true
                                                                        Layout.fillWidth: true
                                                                        elide: Text.ElideRight
                                                                    }

                                                                    Text {
                                                                        text: (pvLoader.item && pvLoader.item.subtitleText) || ""
                                                                        visible: text !== ""
                                                                        color: pvCellSurface.fgColor
                                                                        font.pixelSize: 13
                                                                        font.bold: true
                                                                        Layout.fillWidth: true
                                                                        elide: Text.ElideRight
                                                                    }
                                                                }
                                                            }
                                                        }

                                                        // Block all interaction on preview
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            z: 100
                                                        }
                                                    }
                                                }

                                                // Clickable overlay — tapping adds at this size
                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: pvBg.radius * sc
                                                    color: pvAddMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                                                    border.color: pvAddMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
                                                    border.width: 1
                                                    Behavior on color {
                                                        ColorAnimation {
                                                            duration: 150
                                                        }
                                                    }
                                                    Behavior on border.color {
                                                        ColorAnimation {
                                                            duration: 150
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: pvAddMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            // Appends to the current page, spilling onto a
                                                            // fresh page when the 4x8 grid is full.
                                                            controlPanel.addEntry(
                                                                toggleSection.toggleSource,
                                                                pColSpan,
                                                                pRowSpan
                                                            );
                                                            addControlPopup.close();
                                                        }
                                                    }
                                                }
                                            }

                                            // Size label
                                            Text {
                                                text: pColSpan + "×" + pRowSpan
                                                color: Qt.rgba(1, 1, 1, 0.3)
                                                font.pixelSize: 10
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }
                                }

                                // Divider between sections
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    height: 1
                                    color: Qt.rgba(1, 1, 1, 0.06)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Morph Layer: Status Icons (from StatusCluster → control header) ──
        Row {
            id: morphStatusRow
            anchors.right: parent.right
            anchors.rightMargin: 16 + 32 * qs.smoothMorphProgress
            property real startY: 0
            property real targetY: 18
            y: startY + (targetY - startY) * qs.smoothMorphProgress
            spacing: 12
            visible: !qs.morphComplete
            opacity: 1.0
            height: 20

            // System Tray
            Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        width: 20
                        height: 20
                        Image {
                            id: morphTrayIcon
                            anchors.fill: parent
                            sourceSize: Qt.size(24, 24)
                            fillMode: Image.PreserveAspectFit
                            source: modelData.icon && modelData.icon !== "" ? (modelData.icon.startsWith("/") ? "file://" + modelData.icon : modelData.icon.startsWith("image://") || modelData.icon.startsWith("file://") ? modelData.icon : "image://icon/" + modelData.icon) : ""
                        }
                    }
                }
            }

            // Bluetooth
            Item {
                width: (Bluetooth.bluetoothEnabled && Bluetooth.bluetoothConnected) ? 20 : 0
                height: 20
                visible: width > 0
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    id: morphBtIcon
                    anchors.fill: parent
                    source: Icons.icon(Bluetooth.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
                    sourceSize: Qt.size(24, 24)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: morphBtIcon
                    source: morphBtIcon
                    color: "white"
                }
            }

            // Network
            Item {
                width: Network.networkConnected ? 20 : 0
                height: 20
                visible: width > 0
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    id: morphNetIcon
                    anchors.fill: parent
                    source: {
                        if (Network.networkType === "ethernet")
                            return Icons.icon("network-wired-symbolic");
                        let levels = ["none", "weak", "ok", "good", "excellent"];
                        let level = levels[Network.networkSignalLevel] || "none";
                        return Icons.icon("network-wireless-signal-" + level + "-symbolic");
                    }
                    sourceSize: Qt.size(24, 24)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: morphNetIcon
                    source: morphNetIcon
                    color: "white"
                }
            }

            // Battery
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                Item {
                    width: 20; height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        id: morphBattIcon
                        anchors.fill: parent
                        source: {
                            let isCharging = Battery.batteryStatus === "Charging";
                            let pct = Battery.batteryPct;
                            if (pct < 0) return Icons.icon("battery-missing-symbolic");
                            let level = Math.max(0, Math.min(100, Math.round(pct / 10) * 10));
                            let sLevel = (level < 100 ? (level < 10 ? "00" : "0") : "") + level;
                            let name = "battery-" + sLevel;
                            if (isCharging) name += "-charging";
                            name += "-symbolic";
                            return Icons.icon(name);
                        }
                        sourceSize: Qt.size(24, 24)
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: morphBattIcon
                        source: morphBattIcon
                        color: "white"
                    }
                }
                Text {
                    text: Battery.batteryPct >= 0 ? Battery.batteryPct + "%" : "—"
                    color: "white"
                    font.pixelSize: 15
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Hide after close animation (only when not actively dragging)
        Timer {
            id: hideTimer
            interval: 400
            running: !qs.isOpen && qs.dragOffset === 0
            onTriggered: qs.visible = false
        }
    }
}