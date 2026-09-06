import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects

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

    property bool isOpen: shellRoot.panelOpen
    property real dragOffset: shellRoot.panelDragOffset
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
    property bool wifiEnabled: shellRoot.wifiEnabled
    property bool bluetoothEnabled: shellRoot.bluetoothEnabled

    property int batteryPct: -1
    property string batteryStatus: ""

    function toggleWifi() {
        shellRoot.toggleWifi();
    }
    function toggleBluetooth() {
        shellRoot.toggleBluetooth();
    }

    // ── Brightness ──
    property int brightnessValue: 50
    property int maxBrightness: 100
    property string backlightDevice: ""
    property var backlightCandidates: ["intel_backlight", "amdgpu_bl0", "acpi_video0", "nv_backlight", "apple_backlight", "panasonic_backlight", "sony_backlight"]
    property int backlightProbeIndex: 0

    function detectBacklightDevice() {
        if (qs.backlightDevice !== "") return;
        if (qs.backlightProbeIndex >= qs.backlightCandidates.length) return;
        let d = qs.backlightCandidates[qs.backlightProbeIndex];
        testDeviceProc.command = ["test", "-r", "/sys/class/backlight/" + d + "/brightness"];
        testDeviceProc.deviceName = d;
        testDeviceProc.running = true;
    }

    Component.onCompleted: {
        detectBacklightDevice();
    }

    Process {
        id: testDeviceProc
        property string deviceName: ""
        running: false
        onExited: (code) => {
            if (code === 0) {
                qs.backlightDevice = qs.testDeviceProc.deviceName;
                qs.maxBrightnessProc.running = true;
                qs.brightnessProc.running = true;
            } else {
                qs.backlightProbeIndex++;
                qs.detectBacklightDevice();
            }
        }
    }

    Process {
        id: maxBrightnessProc
        command: ["cat", "/sys/class/backlight/" + qs.backlightDevice + "/max_brightness"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let v = parseInt(data.trim());
                if (!isNaN(v))
                    qs.maxBrightness = v;
            }
        }
    }
    Process {
        id: brightnessProc
        command: ["cat", "/sys/class/backlight/" + qs.backlightDevice + "/brightness"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let v = parseInt(data.trim());
                if (!isNaN(v) && qs.maxBrightness > 0)
                    qs.brightnessValue = Math.round((v / qs.maxBrightness) * 100);
            }
        }
    }
    Process {
        id: setBrightnessProc
        running: false
    }

    function setBrightness(pct) {
        brightnessValue = pct;
        let raw = Math.round((pct / 100.0) * maxBrightness);
        setBrightnessProc.command = ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", backlightDevice, String(raw)];
        setBrightnessProc.running = true;
    }

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
            source: shellRoot.blurredWallpaperPath
            cache: true
            fillMode: Image.PreserveAspectCrop

            Connections {
                target: shellRoot
                function onBlurVersionChanged() {
                    let s = bgBlur.source;
                    bgBlur.source = "";
                    bgBlur.source = s;
                }
            }
            visible: shellRoot.usePrecomputedBlur && shellRoot.staticBlurEnabled
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
                        shellRoot.panelDragOffset = dy;
                    }
                }
            }
            onReleased: mouse => {
                if (isDragging) {
                    if (shellRoot.panelDragOffset < -60) {
                        shellRoot.panelOpen = false;
                    }
                    shellRoot.panelDragOffset = 0;
                    isDragging = false;
                } else {
                    // If expanded view is open, close it instead of the whole panel
                    if (expandedOverlay.isExpanded) {
                        controlPanel.closeExpandedView();
                    } else {
                        shellRoot.panelOpen = false;
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
                        shellRoot.panelDragOffset = dy;
                    }
                }
            }
            onReleased: mouse => {
                if (isDragging) {
                    if (shellRoot.panelDragOffset < -60) {
                        shellRoot.panelOpen = false;
                    }
                    shellRoot.panelDragOffset = 0;
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
                    visible: notificationServer.notificationList.length > 0
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: notificationServer.clearAll()
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
                let list = notificationServer.notificationList;
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
                                                    notificationServer.dismiss(stackedTopCard.notif.id);
                                                } else {
                                                    notificationServer.dismissByApp(group.appName);
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
                                            source: shellRoot.icon("go-up-symbolic")
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
                                            source: shellRoot.icon("edit-clear-all-symbolic")
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
                                            onClicked: notificationServer.dismissByApp(group.appName)
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
                                                            source: shellRoot.icon("window-close-symbolic")
                                                            opacity: closeBtnMouse.containsMouse ? 1.0 : 0.6
                                                        }

                                                        MouseArea {
                                                            id: closeBtnMouse
                                                            anchors.fill: parent
                                                            anchors.margins: -6
                                                            hoverEnabled: true
                                                            onClicked: notificationServer.dismiss(notif.id)
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
                                            onTriggered: notificationServer.dismiss(swipeContainer.notif.id)
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
                        visible: notificationServer.notificationList.length === 0
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
            height: 830
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
                parent: toggleFlickable.contentItem
                z: 300

                Drag.active: controlPanel.dragIndex >= 0
                Drag.keys: ["toggle"]
                Drag.hotSpot.x: 10
                Drag.hotSpot.y: 10

                property Item sourceDelegate: null
            }

            property var defaultLayout: [
                {
                    source: "toggles/NetworkToggle.qml",
                    colSpan: 2,
                    rowSpan: 1
                },
                {
                    source: "toggles/BluetoothToggle.qml",
                    colSpan: 2,
                    rowSpan: 1
                },
                {
                    source: "toggles/PowerProfileToggle.qml",
                    colSpan: 2,
                    rowSpan: 1
                },
                {
                    source: "toggles/MediaWidget.qml",
                    colSpan: 2,
                    rowSpan: 2
                },
                {
                    source: "toggles/BrightnessSlider.qml",
                    colSpan: 2,
                    rowSpan: 1
                },
                {
                    source: "toggles/VolumeSlider.qml",
                    colSpan: 2,
                    rowSpan: 1
                },
                {
                    source: "toggles/SettingsToggle.qml",
                    colSpan: 1,
                    rowSpan: 1
                },
                {
                    source: "toggles/LockToggle.qml",
                    colSpan: 1,
                    rowSpan: 1
                },
                {
                    source: "toggles/PowerToggle.qml",
                    colSpan: 1,
                    rowSpan: 1
                },
                {
                    source: "toggles/DndToggle.qml",
                    colSpan: 1,
                    rowSpan: 1
                },
                {
                    source: "toggles/CaffeineToggle.qml",
                    colSpan: 1,
                    rowSpan: 1
                }
            ]

            property bool layoutApplied: false

            function applyLayout(items) {
                togglesModel.clear();
                if (!Array.isArray(items)) {
                    console.warn("[QuickSettings] Layout is not an array, using default");
                    items = controlPanel.defaultLayout;
                }
                for (let i = 0; i < items.length; i++) {
                    let entry = items[i];
                    // Validate entry: must be object with source string
                    if (!entry || typeof entry !== "object" || typeof entry.source !== "string" || entry.source === "") {
                        console.warn("[QuickSettings] Skipping invalid layout entry at index", i);
                        continue;
                    }
                    // Clamp span values to valid range
                    let colSpan = Math.max(1, Math.min(4, parseInt(entry.colSpan) || 1));
                    let rowSpan = Math.max(1, Math.min(4, parseInt(entry.rowSpan) || 1));
                    togglesModel.append({ source: entry.source, colSpan: colSpan, rowSpan: rowSpan });
                }
                controlPanel.layoutApplied = true;
            }

            Connections {
                target: shellRoot
                function onConfigLoadCompleteChanged() {
                    console.log("[QuickSettings] Config load complete:", shellRoot.configLoadComplete);
                    console.log("[QuickSettings] Layout from shell:", JSON.stringify(shellRoot.controlCenterLayout));
                    if (controlPanel.layoutApplied || !shellRoot.configLoadComplete) return;
                    if (shellRoot.controlCenterLayout && shellRoot.controlCenterLayout.length > 0) {
                        console.log("[QuickSettings] Applying saved layout");
                        controlPanel.applyLayout(shellRoot.controlCenterLayout);
                    } else {
                        console.log("[QuickSettings] Applying default layout");
                        controlPanel.applyLayout(controlPanel.defaultLayout);
                    }
                }
            }

            Component.onCompleted: {
                if (shellRoot.configLoadComplete && !controlPanel.layoutApplied) {
                    if (shellRoot.controlCenterLayout && shellRoot.controlCenterLayout.length > 0) {
                        controlPanel.applyLayout(shellRoot.controlCenterLayout);
                    } else {
                        controlPanel.applyLayout(controlPanel.defaultLayout);
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

            // Helper that performs the actual snap. Public entry point is
            // openExpandedView(); replayPendingOpen() drives it after the
            // panel bloom finishes.
            function doOpenExpandedView(sourceRect, widgetItem, delegateRef) {
                // sourceRect is the widgetBg being morphed. It already
                // lives under gridWrapper at its cell-bound position
                // (Phase D no longer needs to reparent a separate card).
                // We capture its current position so close() can animate
                // back without relying on the live (animated) values,
                // which would drift during the morph.
                let pos = sourceRect.mapToItem(gridWrapper, 0, 0);
                expandedOverlay.sourceItem = sourceRect;
                expandedOverlay.widgetItem = widgetItem;
                expandedOverlay.startX = pos.x;
                expandedOverlay.startY = pos.y;
                expandedOverlay.startWidth = sourceRect.width;
                expandedOverlay.startHeight = sourceRect.height;
                // Capture the source widget's natural radius so close()
                // animates back to the source's actual shape. For 1x1
                // toggles this is the circle radius (width/height/2);
                // for 2x2 toggles the source uses a 16px rounded square,
                // so we fall back to 24px (the slightly tighter inner
                // card radius) to avoid a visible flatten-then-pop.
                expandedOverlay.sourceRadius =
                    (sourceRect.width === sourceRect.height)
                        ? sourceRect.width / 2
                        : 24;

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

            function saveLayout() {
                let items = [];
                for (let i = 0; i < togglesModel.count; i++) {
                    let item = togglesModel.get(i);
                    items.push({
                        source: item.source,
                        colSpan: item.colSpan,
                        rowSpan: item.rowSpan
                    });
                }
                shellRoot.controlCenterLayout = items;
                shellRoot.saveConfig();
            }

            function resetLayout() {
                applyLayout(defaultLayout);
                saveLayout();
            }

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
                            width: (shellRoot.bluetoothEnabled && shellRoot.bluetoothConnected) ? 20 : 0
                            height: 20
                            visible: width > 0
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: btIconMorph
                                anchors.fill: parent
                                source: shellRoot.icon(shellRoot.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
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
                            width: shellRoot.networkConnected ? 20 : 0
                            height: 20
                            visible: width > 0
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: networkIconMorph
                                anchors.fill: parent
                                source: {
                                    if (shellRoot.networkType === "ethernet") {
                                        return shellRoot.icon("network-wired-symbolic");
                                    }

                                    let levels = ["none", "weak", "ok", "good", "excellent"];
                                    let level = levels[shellRoot.networkSignalLevel] || "none";
                                    return shellRoot.icon("network-wireless-signal-" + level + "-symbolic");
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
                                        let isCharging = qs.batteryStatus === "Charging";
                                        let pct = qs.batteryPct;
                                        if (pct < 0)
                                            return shellRoot.icon("battery-missing-symbolic");
                                        let level = Math.max(0, Math.min(100, Math.round(pct / 10) * 10));
                                        let sLevel = (level < 100 ? (level < 10 ? "00" : "0") : "") + level;
                                        let name = "battery-" + sLevel;
                                        if (isCharging)
                                            name += "-charging";
                                        name += "-symbolic";
                                        return shellRoot.icon(name);
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
                                text: qs.batteryPct >= 0 ? qs.batteryPct + "%" : "—"
                                color: "white"
                                font.pixelSize: 15
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Edit Button
                    Rectangle {
                        width: 60
                        height: 28
                        radius: 14
                        color: controlPanel.editMode ? Qt.rgba(0.2, 0.5, 1.0, 1.0) : Qt.rgba(1, 1, 1, 0.1)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left

                        Text {
                            anchors.centerIn: parent
                            text: controlPanel.editMode ? "Done" : "Edit"
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (controlPanel.editMode) {
                                    controlPanel.saveLayout();
                                }
                                controlPanel.editMode = !controlPanel.editMode;
                            }
                        }
                    }
                }
                // Toggles Model (populated from JSON at startup)
                ListModel {
                    id: togglesModel
                }

                // ── Customizable Quick toggles grid ──
                Flickable {
                    id: toggleFlickable
                    anchors.top: controlHeader.bottom
                    anchors.topMargin: 16
                    height: Math.min(parent.height - y - 24, contentHeight || 0)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    contentHeight: flickableContent.implicitHeight
                    clip: true
                    opacity: progress // Non-morphing content fades in
                    interactive: controlPanel.dragIndex === -1 // Allow scrolling even in edit mode, unless dragging

                    ColumnLayout {
                        id: flickableContent
                        width: parent.width
                        spacing: 24

                        // Stay at full opacity while the expanded view is
                        // open. The source widget's per-instance opacity
                        // binding (line ~1572) still fades it out cleanly,
                        // and the expanded card's z: 200 + MaterialSurface
                        // background covers everything underneath.
                        // The previous binding (which dropped to 0 / 0.2
                        // when expanded) made the entire panel "dissolve"
                        // instead of the toggle "morph".
                        opacity: 1.0

                        Item {
                            id: gridWrapper
                            Layout.fillWidth: true
                            Layout.preferredHeight: toggleGrid.implicitHeight

                            GridLayout {
                                id: toggleGrid
                                anchors.fill: parent
                                columns: 4
                                rowSpacing: 16
                                columnSpacing: 16

                                Repeater {
                                    model: togglesModel
                                    delegate: Item {
                                        id: delegateItem
                                        property int itemIndex: index
                                        property bool isDragging: controlPanel.dragIndex === index

                                        // Keep the layout slot full size so it acts as a placeholder
                                        Layout.columnSpan: model.colSpan
                                        Layout.rowSpan: model.rowSpan
                                        Layout.fillWidth: true
                                        property real colWidth: Math.max(0, (toggleGrid.width - (3 * toggleGrid.columnSpacing)) / 4)
                                        Layout.preferredWidth: (model.colSpan * colWidth) + ((model.colSpan - 1) * toggleGrid.columnSpacing)
                                        Layout.minimumWidth: Layout.preferredWidth
                                        Layout.maximumWidth: Layout.preferredWidth
                                        Layout.preferredHeight: (model.rowSpan * ((400 - 48 - 48) / 4)) + ((model.rowSpan - 1) * 16)

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
                                                    togglesModel.move(fromIdx, targetIdx, 1);
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
                                                isActive: {
                                                    if (!widgetLoader.item)
                                                        return false;
                                                    if (widgetLoader.item.isSimpleToggle && model.colSpan >= 2)
                                                        return false;
                                                    return !!widgetLoader.item.isActive;
                                                }
                                                accentColor: (widgetLoader.item && widgetLoader.item.activeColor) ? widgetLoader.item.activeColor : (shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
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
                                                enabled: !controlPanel.editMode && widgetLoader.item !== null && widgetLoader.item.hasExpandedView === true && widgetLoader.item.isSimpleToggle !== true
                                                pressAndHoldInterval: 300
                                                onPressAndHold: {
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
                                                    // Connect expandRequested signal for widgets that handle their own hold detection
                                                    if (item && item.expandRequested) {
                                                        item.expandRequested.connect(function () {
                                                            if (!controlPanel.editMode && item.hasExpandedView) {
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
                                                            accentColor: (widgetLoader.item && widgetLoader.item.activeColor) ? widgetLoader.item.activeColor : (shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
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
                                                            accentColor: (widgetLoader.item && widgetLoader.item.activeColor) ? widgetLoader.item.activeColor : (shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
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
                                                    enabled: !controlPanel.editMode
                                                    pressAndHoldInterval: 300
                                                    Accessible.name: (widgetLoader.item && widgetLoader.item.toggleName) || "Toggle"
                                                    Accessible.role: Accessible.Button
                                                    onClicked: {
                                                        if (widgetLoader.item && widgetLoader.item.toggled)
                                                            widgetLoader.item.toggled();
                                                    }
                                                    onPressAndHold: {
                                                        if (widgetLoader.item && widgetLoader.item.hasExpandedView) {
                                                            controlPanel.openExpandedView(widgetBg, widgetLoader.item, delegateItem);
                                                        }
                                                    }
                                                }
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
                                                // instantiates the expanded view. Phase D
                                                // moved this Loader from a singleton (inside
                                                // the deleted expandedCard) into per-cell
                                                // widgetBg but forgot to gate active/opacity
                                                // on the source check, so every cell ended
                                                // up showing the expanded view simultaneously.
                                                active: expandedOverlay.sourceItem === widgetBg
                                                sourceComponent: (expandedOverlay.isExpanded && widgetLoader.item) ? widgetLoader.item.expandedComponent : null
                                                opacity: (expandedOverlay.isExpanded && expandedOverlay.sourceItem === widgetBg) ? 1.0 : 0.0
                                                Behavior on opacity {
                                                    NumberAnimation {
                                                        duration: 200
                                                    }
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

                                                // Position tracker at widgetBg's center in flickable coordinates
                                                let fPos = widgetBg.mapToItem(toggleFlickable.contentItem, widgetBg.width / 2, widgetBg.height / 2);
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

                                                // Update invisible tracker in flickable coordinates
                                                let fp = toggleFlickable.contentItem.mapFromItem(null, globalX, globalY);
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
                                                togglesModel.remove(index);
                                            }
                                            onResized: (newColSpan, newRowSpan) => {
                                                togglesModel.setProperty(index, "colSpan", newColSpan);
                                                togglesModel.setProperty(index, "rowSpan", newRowSpan);
                                            }
                                        }
                                    }
                                } // closes Repeater
                            } // closes GridLayout
                        } // closes gridWrapper

                        // ── Add a Control Button ──
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 48
                            width: 160
                            height: 36
                            radius: 18
                            color: Qt.rgba(0.15, 0.15, 0.2, 0.8)
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            border.width: 1
                            visible: controlPanel.editMode

                            Row {
                                anchors.centerIn: parent
                                spacing: 8
                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: "transparent"
                                    border.color: "white"
                                    border.width: 1
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

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    addControlPopup.open();
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

            Rectangle {
                id: addControlPopup
                anchors.fill: parent
                radius: 16
                color: "transparent"
                visible: opacity > 0

                MaterialSurface {
                    anchors.fill: parent
                    radius: parent.radius
                }
                opacity: 0
                z: 100
                scale: opacity > 0.5 ? 1.0 : 0.9

                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }

                function open() {
                    opacity = 1.0;
                }
                function close() {
                    opacity = 0.0;
                }

                // Preview metrics — matches the real grid math
                readonly property real realCellSize: 76  // (400 - 48 - 48) / 4
                readonly property real realGridSpacing: 16
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
                                source: shellRoot.icon("window-close-symbolic")
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
                                                            color: Qt.rgba(0.15, 0.15, 0.2, 0.8)
                                                            clip: true

                                                             layer.enabled: qs.isOpen || qs.dragOffset > 0
                                                             layer.effect: OpacityMask {
                                                                 maskSource: Rectangle {
                                                                     width: pvBg.width
                                                                     height: pvBg.height
                                                                     radius: pvBg.radius
                                                                 }
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
                                                            Rectangle {
                                                                id: pvChrome
                                                                anchors.fill: parent
                                                                visible: pvLoader.item && pvLoader.item.isSimpleToggle === true
                                                                radius: pvBg.radius
                                                                color: {
                                                                    if (!pvLoader.item || !pvLoader.item.isSimpleToggle)
                                                                        return "transparent";
                                                                    if (pColSpan === 2 && pRowSpan === 2)
                                                                        return "transparent";
                                                                    return pvLoader.item.isActive ? (pvLoader.item.activeColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)) : "transparent";
                                                                }

                                                                // ── Non-2x2 layout (1x1 circles, 2x1 pills) ──
                                                                GridLayout {
                                                                    visible: !(pColSpan === 2 && pRowSpan === 2)
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    x: pColSpan > pRowSpan ? (parent.height / 2 - 16) : 8
                                                                    width: pColSpan > pRowSpan ? (parent.width - x - 16) : (parent.width - 16)
                                                                    columns: pColSpan > pRowSpan ? 2 : 1
                                                                    rowSpacing: 8
                                                                    columnSpacing: 12

                                                                    Image {
                                                                        Layout.alignment: Qt.AlignCenter
                                                                        width: (pColSpan === 1 && pRowSpan === 1) ? 24 : 32
                                                                        height: width
                                                                        sourceSize: Qt.size(width, width)
                                                                        source: (pvLoader.item && pvLoader.item.iconSource) || ""
                                                                    }

                                                                    ColumnLayout {
                                                                        visible: pColSpan > 1
                                                                        Layout.alignment: pColSpan > pRowSpan ? Qt.AlignVCenter | Qt.AlignLeft : Qt.AlignHCenter
                                                                        Layout.fillWidth: pColSpan > pRowSpan
                                                                        spacing: 0

                                                                        Text {
                                                                            text: (pvLoader.item && (pvLoader.item.titleText !== undefined ? pvLoader.item.titleText : pvLoader.item.toggleName)) || ""
                                                                            color: "white"
                                                                            font.pixelSize: 14
                                                                            font.bold: true
                                                                            Layout.fillWidth: true
                                                                            horizontalAlignment: pColSpan > pRowSpan ? Text.AlignLeft : Text.AlignHCenter
                                                                            elide: Text.ElideRight
                                                                        }

                                                                        Text {
                                                                            text: (pvLoader.item && pvLoader.item.subtitleText) || ""
                                                                            visible: text !== ""
                                                                            color: Qt.rgba(1, 1, 1, 0.6)
                                                                            font.pixelSize: 12
                                                                            Layout.fillWidth: true
                                                                            horizontalAlignment: pColSpan > pRowSpan ? Text.AlignLeft : Text.AlignHCenter
                                                                            elide: Text.ElideRight
                                                                        }
                                                                    }
                                                                }

                                                                // ── 2x2 layout ──
                                                                Item {
                                                                    anchors.fill: parent
                                                                    visible: pColSpan === 2 && pRowSpan === 2

                                                                    Rectangle {
                                                                        width: 48
                                                                        height: 48
                                                                        radius: 24
                                                                        anchors.top: parent.top
                                                                        anchors.topMargin: 16
                                                                        anchors.left: parent.left
                                                                        anchors.leftMargin: 16
                                                                        color: {
                                                                            if (!pvLoader.item || !pvLoader.item.isSimpleToggle)
                                                                                return Qt.rgba(1, 1, 1, 0.1);
                                                                            return pvLoader.item.isActive ? (pvLoader.item.activeColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)) : Qt.rgba(1, 1, 1, 0.1);
                                                                        }

                                                                        Image {
                                                                            anchors.centerIn: parent
                                                                            width: 24
                                                                            height: 24
                                                                            sourceSize: Qt.size(24, 24)
                                                                            source: (pvLoader.item && pvLoader.item.iconSource) || ""
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
                                                                            color: "white"
                                                                            font.pixelSize: 14
                                                                            font.bold: true
                                                                            Layout.fillWidth: true
                                                                            elide: Text.ElideRight
                                                                        }

                                                                        Text {
                                                                            text: (pvLoader.item && pvLoader.item.subtitleText) || ""
                                                                            visible: text !== ""
                                                                            color: Qt.rgba(1, 1, 1, 0.6)
                                                                            font.pixelSize: 12
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
                                                                togglesModel.append({
                                                                    source: toggleSection.toggleSource,
                                                                    colSpan: pColSpan,
                                                                    rowSpan: pRowSpan
                                                                });
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

            // ── Expanded View Overlay (Phase D slimmed) ──
            // Only two responsibilities remain:
            //   1. Click-to-close backdrop (this Item itself, full-overlay,
            //      with a MouseArea that catches outside-click to close).
            //   2. State owner: isExpanded, deferred-open slot, per-open
            //      geometry parameters (startX/Y/Width/Height, sourceRadius,
            //      computedTargetHeight), and open()/close() that drive the
            //      morph on `sourceItem` (which is now widgetBg itself,
            //      reparented into gridWrapper since Phase B).
            //
            // No morph container lives here anymore. expandedCard is gone;
            // expandedLoader lives inside widgetBg.
            Item {
                id: expandedOverlay
                anchors.fill: parent
                visible: opacity > 0
                opacity: 0
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
                property real startX: 0
                property real startY: 0
                property real startWidth: 0
                property real startHeight: 0
                // Source widget's natural radius captured at open() time.
                // Used by close() to animate back to the source's actual
                // shape without depending on the live (animated) width/
                // height values, which would drift during the morph.
                property real sourceRadius: 0
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
                    isExpanded = true;
                    opacity = 1.0;

                    // Resolve the expanded component (already lives inside
                    // widgetBg now, so no sourceComponent assignment is
                    // needed here — expandedLoader reads widgetItem directly
                    // via its binding). Still compute target height so the
                    // morph lands at the right final bounds.
                    let w = widgetItem;
                    let implicitH = (w && w.implicitHeight > 0) ? w.implicitHeight + 48 : 0;
                    let explicitH = (w && w.expandedHeight > 0) ? w.expandedHeight : 0;
                    let targetH = implicitH > 0 ? implicitH : (explicitH > 0 ? explicitH : 420);

                    let maxH = Math.min(gridWrapper.height - 40, 680);
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
                        sourceItem.x = 0;
                        sourceItem.y = (gridWrapper.height - targetH) / 2;
                        sourceItem.width = gridWrapper.width;
                        sourceItem.height = targetH;
                        sourceItem.radius = 16;
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
                        sourceItem.x = startX;
                        sourceItem.y = startY;
                        sourceItem.width = startWidth;
                        sourceItem.height = startHeight;
                        sourceItem.radius = sourceRadius > 0 ? sourceRadius : 24;
                    }

                    isExpanded = false;
                    opacity = 0.0;

                    // After the close morph lands, snap the widgetBg
                    // geometry bindings back to the cell-bound form. Using
                    // Qt.binding() restores the original conditional
                    // bindings (lines ~1563-1565) so the toggle reappears
                    // with its natural radius (auto-computed from cell
                    // size for 1x1 circles, fixed 16 for 2x2+).
                    morphCompleteTimer.restart();
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
                        let cs = 0;
                        let rs = 0;
                        try {
                            cs = del && del.model ? del.model.colSpan : (del && del.Layout ? del.Layout.columnSpan : 0);
                            rs = del && del.model ? del.model.rowSpan : (del && del.Layout ? del.Layout.rowSpan : 0);
                        } catch (e) {}
                        s.morphState = "idle";
                        s.x = Qt.binding(function() { return del ? del.x : 0; });
                        s.y = Qt.binding(function() { return del ? del.y : 0; });
                        s.width = Qt.binding(function() { return del ? del.width : 0; });
                        s.height = Qt.binding(function() { return del ? del.height : 0; });
                        s.radius = Qt.binding(function() {
                            return (cs >= 2 && rs >= 2)
                                ? 16 : Math.min(width, height) / 2;
                        });
                        expandedOverlay.delegateItemRef = null;
                    }
                }

                // Replay a deferred open() once the panel's bloom-scale
                // spring has settled. Watches qs.morphComplete (set by
                // onSmoothMorphProgressChanged when smoothMorphProgress
                // reaches 1.0).
                Connections {
                    target: qs
                    function onMorphCompleteChanged() {
                        if (qs.morphComplete)
                            replayPendingOpen();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: expandedOverlay.close()
                }
            }
        } // closes controlPanel

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
                width: (shellRoot.bluetoothEnabled && shellRoot.bluetoothConnected) ? 20 : 0
                height: 20
                visible: width > 0
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    id: morphBtIcon
                    anchors.fill: parent
                    source: shellRoot.icon(shellRoot.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
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
                width: shellRoot.networkConnected ? 20 : 0
                height: 20
                visible: width > 0
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    id: morphNetIcon
                    anchors.fill: parent
                    source: {
                        if (shellRoot.networkType === "ethernet")
                            return shellRoot.icon("network-wired-symbolic");
                        let levels = ["none", "weak", "ok", "good", "excellent"];
                        let level = levels[shellRoot.networkSignalLevel] || "none";
                        return shellRoot.icon("network-wireless-signal-" + level + "-symbolic");
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
                            let isCharging = qs.batteryStatus === "Charging";
                            let pct = qs.batteryPct;
                            if (pct < 0) return shellRoot.icon("battery-missing-symbolic");
                            let level = Math.max(0, Math.min(100, Math.round(pct / 10) * 10));
                            let sLevel = (level < 100 ? (level < 10 ? "00" : "0") : "") + level;
                            let name = "battery-" + sLevel;
                            if (isCharging) name += "-charging";
                            name += "-symbolic";
                            return shellRoot.icon(name);
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
                    text: qs.batteryPct >= 0 ? qs.batteryPct + "%" : "—"
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
