import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
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
    
    WlrLayershell.keyboardFocus: (isOpen || visible) ? WlrLayershell.OnDemand : WlrLayershell.None

    property bool isOpen: shellRoot.panelOpen
    property real dragOffset: shellRoot.panelDragOffset
    property real progress: {
        if (!isOpen && dragOffset > 0) return Math.min(1.0, dragOffset / 60.0);
        if (isOpen && dragOffset < 0) return Math.max(0.0, 1.0 - (Math.abs(dragOffset) / 60.0));
        return isOpen ? 1.0 : 0.0;
    }

    // ── Pipewire audio ──
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null

    // ── Connectivity ──
    property bool wifiEnabled: shellRoot.wifiEnabled
    property bool bluetoothEnabled: shellRoot.bluetoothEnabled

    property int batteryPct: -1
    property string batteryStatus: ""


    function toggleWifi() {
        shellRoot.toggleWifi()
    }
    function toggleBluetooth() {
        shellRoot.toggleBluetooth()
    }

    // ── Brightness ──
    property int brightnessValue: 50
    property int maxBrightness: 100
    property string backlightDevice: "intel_backlight"

    Component.onCompleted: { maxBrightnessProc.running = true; brightnessProc.running = true }

    Process { id: maxBrightnessProc; command: ["cat", "/sys/class/backlight/" + qs.backlightDevice + "/max_brightness"]; running: false
        stdout: SplitParser { onRead: data => { let v = parseInt(data.trim()); if (!isNaN(v)) qs.maxBrightness = v } }
    }
    Process { id: brightnessProc; command: ["cat", "/sys/class/backlight/" + qs.backlightDevice + "/brightness"]; running: false
        stdout: SplitParser { onRead: data => { let v = parseInt(data.trim()); if (!isNaN(v) && qs.maxBrightness > 0) qs.brightnessValue = Math.round((v / qs.maxBrightness) * 100) } }
    }
    Process { id: setBrightnessProc; running: false }

    function setBrightness(pct) {
        brightnessValue = pct
        let raw = Math.round((pct / 100.0) * maxBrightness)
        setBrightnessProc.command = ["busctl", "call", "org.freedesktop.login1",
            "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session",
            "SetBrightness", "ssu", "backlight", backlightDevice, String(raw)]
        setBrightnessProc.running = true
    }

    // ── Drag / open animation ──
    onDragOffsetChanged: {
        let progress = 0.0
        if (!isOpen && dragOffset > 0) {
            // Dragging down while closed
            progress = Math.min(1.0, dragOffset / 60.0)
            qs.visible = true
            panelBehavior.enabled = false
            scaleBehavior.enabled = false
            opacityBehavior.enabled = false
            bgOpacityBehavior.enabled = false
        } else if (isOpen && dragOffset < 0) {
            // Dragging up while open
            progress = Math.max(0.0, 1.0 - (Math.abs(dragOffset) / 60.0))
            panelBehavior.enabled = false
            scaleBehavior.enabled = false
            opacityBehavior.enabled = false
            bgOpacityBehavior.enabled = false
        } else if (dragOffset === 0) {
            panelBehavior.enabled = true
            scaleBehavior.enabled = true
            opacityBehavior.enabled = true
            bgOpacityBehavior.enabled = true
            progress = isOpen ? 1.0 : 0.0
            if (isOpen) qs.visible = true
        }
        
        // Calculate physics values
        panelContainer.y = 10 + (progress * 40)
        panelContainer.bloomScale = 0.85 + (progress * 0.15)
        panelContainer.opacity = progress > 0 ? 1.0 : 0.0 // Instant opacity for morphing elements
        bgDim.opacity = progress
    }

    onIsOpenChanged: {
        panelBehavior.enabled = true
        scaleBehavior.enabled = true
        opacityBehavior.enabled = true
        bgOpacityBehavior.enabled = true
        if (isOpen) {
            qs.visible = true
            panelContainer.y = 50
            panelContainer.bloomScale = 1.0
            panelContainer.opacity = 1.0
            bgDim.opacity = 1.0
        } else {
            if (expandedOverlay.isExpanded) controlPanel.closeExpandedView()
            panelContainer.y = 10
            panelContainer.bloomScale = 0.85
            panelContainer.opacity = 0.0
            bgDim.opacity = 0.0
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
            visible: shellRoot.usePrecomputedBlur
        }
        
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.3)
        }

        Behavior on opacity {
            id: bgOpacityBehavior
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
        }

        MouseArea {
            anchors.fill: parent
            property real startY: 0
            property bool isDragging: false

            onPressed: (mouse) => {
                startY = mapToItem(null, mouse.x, mouse.y).y
                isDragging = false
            }
            onPositionChanged: (mouse) => {
                if (isOpen) {
                    let mappedY = mapToItem(null, mouse.x, mouse.y).y
                    let dy = mappedY - startY
                    if (dy < -10) {
                        isDragging = true
                        shellRoot.panelDragOffset = dy
                    }
                }
            }
            onReleased: (mouse) => {
                if (isDragging) {
                    if (shellRoot.panelDragOffset < -60) {
                        shellRoot.panelOpen = false
                    }
                    shellRoot.panelDragOffset = 0
                    isDragging = false
                } else {
                    // If expanded view is open, close it instead of the whole panel
                    if (expandedOverlay.isExpanded) {
                        controlPanel.closeExpandedView()
                    } else {
                        shellRoot.panelOpen = false
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

        onOpacityChanged: {
            if (opacity <= 0.01 && !isOpen && dragOffset === 0) {
                qs.visible = false
            }
        }

        Behavior on y {
            id: panelBehavior
            NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
        }
        Behavior on bloomScale {
            id: scaleBehavior
            NumberAnimation { duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        Behavior on opacity {
            id: opacityBehavior
            NumberAnimation { duration: 300; easing.type: Easing.OutExpo }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            property real startY: 0
            property bool isDragging: false

            onPressed: (mouse) => {
                startY = mapToItem(null, mouse.x, mouse.y).y
                isDragging = false
            }
            onPositionChanged: (mouse) => {
                if (isOpen) {
                    let mappedY = mapToItem(null, mouse.x, mouse.y).y
                    let dy = mappedY - startY
                    if (dy < -10) {
                        isDragging = true
                        shellRoot.panelDragOffset = dy
                    }
                }
            }
            onReleased: (mouse) => {
                if (isDragging) {
                    if (shellRoot.panelDragOffset < -60) {
                        shellRoot.panelOpen = false
                    }
                    shellRoot.panelDragOffset = 0
                    isDragging = false
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
                interval: 1000; running: true; repeat: true
                onTriggered: {
                    notifPanel.timeString = Qt.formatTime(new Date(), "HH:mm")
                    notifPanel.dateString = Qt.formatDate(new Date(), "dddd, MMMM d")
                }
            }

            Row {
                id: clockArea
                // Morphing Logic:
                // Start: StatusBar position (x: 16, y: (40-15)/2 - panelY)
                // End: Notification Panel position (margin 24)
                
                property real targetX: 24
                property real targetY: 24
                property real startX: 16 - notifPanel.anchors.leftMargin
                property real startY: 10 - panelContainer.y - notifPanel.anchors.topMargin // Approximate status bar y

                x: startX + (targetX - startX) * progress
                y: startY + (targetY - startY) * progress
                
                spacing: 16

                Text {
                    id: timeText
                    text: notifPanel.timeString
                    color: "white"
                    font.pixelSize: 15 + (56 - 15) * progress
                    font.bold: true
                }
                Text {
                    text: notifPanel.dateString
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 18
                    opacity: progress
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

            // Notification List
            ListView {
                id: notifListView
                opacity: progress // Non-morphing content fades in
                anchors.top: notifHeader.bottom
                anchors.topMargin: 12
                height: Math.min(parent.height - y - 10, contentHeight || 0)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                clip: true
                spacing: 10

                model: notificationServer.notificationList

                    delegate: Rectangle {
                        width: notifListView.width
                        height: Math.max(80, notifTextCol.implicitHeight + 36)
                        radius: 16
                        color: Qt.rgba(0.15, 0.15, 0.2, 0.7)

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 14

                            // App icon
                            Rectangle {
                                width: 44; height: 44; radius: 8
                                color: Qt.rgba(1, 1, 1, 0.1)
                                Layout.alignment: Qt.AlignTop

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.appName.charAt(0).toUpperCase()
                                    color: "white"
                                    font.pixelSize: 20
                                    font.bold: true
                                    visible: modelData.appIcon === ""
                                }

                                Image {
                                    anchors.centerIn: parent
                                    width: 32; height: 32
                                    source: modelData.appIcon !== "" && modelData.appIcon.startsWith("/") ? "file://" + modelData.appIcon : ""
                                    fillMode: Image.PreserveAspectFit
                                    visible: source !== ""
                                }
                            }

                            ColumnLayout {
                                id: notifTextCol
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.summary
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Image {
                                    width: 16; height: 16
                                    sourceSize: Qt.size(24, 24)
                                    source: shellRoot.icon("window-close-symbolic")
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        onClicked: notificationServer.dismiss(modelData.id)
                                    }
                                }
                            }

                            Text {
                                id: notifBodyText
                                text: modelData.body
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                visible: text !== ""
                            }
                        }
                    }
                }

                // Empty state
                Text {
                    anchors.centerIn: parent
                    text: "No new notifications"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pixelSize: 16
                    visible: notifListView.count === 0
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

            property var defaultLayout: [
                { source: "toggles/WifiToggle.qml",       colSpan: 2, rowSpan: 1 },
                { source: "toggles/BluetoothToggle.qml",  colSpan: 2, rowSpan: 1 },
                { source: "toggles/PowerProfileToggle.qml", colSpan: 2, rowSpan: 1 },
                { source: "toggles/MediaWidget.qml",      colSpan: 2, rowSpan: 2 },
                { source: "toggles/BrightnessSlider.qml", colSpan: 2, rowSpan: 1 },
                { source: "toggles/VolumeSlider.qml",     colSpan: 2, rowSpan: 1 },
                { source: "toggles/SettingsToggle.qml",   colSpan: 1, rowSpan: 1 },
                { source: "toggles/LockToggle.qml",       colSpan: 1, rowSpan: 1 },
                { source: "toggles/PowerToggle.qml",      colSpan: 1, rowSpan: 1 },
                { source: "toggles/DndToggle.qml",        colSpan: 1, rowSpan: 1 }
            ]

            Component.onCompleted: loadLayoutProc.running = true

            property bool ignoreNextChange: false

            Process {
                id: fileWatcherProc
                command: [
                    "python3", "-c",
                    "import time, os, sys; p=sys.argv[1]; lm=os.stat(p).st_mtime if os.path.exists(p) else 0;\nwhile True:\n time.sleep(1)\n try: m=os.stat(p).st_mtime\n except: m=0\n if m!=lm:\n  print('changed', flush=True); lm=m",
                    Qt.resolvedUrl("../config/control_center_layout.json").toString().replace("file://", "")
                ]
                running: true
                stdout: SplitParser {
                    onRead: data => {
                        if (data.trim() === "changed") {
                            if (controlPanel.ignoreNextChange) {
                                controlPanel.ignoreNextChange = false;
                            } else {
                                loadLayoutProc.running = true;
                            }
                        }
                    }
                }
            }

            Process {
                id: loadLayoutProc
                command: ["cat", Qt.resolvedUrl("../config/control_center_layout.json").toString().replace("file://", "")]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            let items = JSON.parse(text)
                            if (Array.isArray(items) && items.length > 0) {
                                controlPanel.applyLayout(items)
                            } else {
                                controlPanel.applyLayout(controlPanel.defaultLayout)
                            }
                        } catch(e) {
                            console.warn("Layout load error, using defaults:", e)
                            controlPanel.applyLayout(controlPanel.defaultLayout)
                        }
                    }
                }
            }

            Process {
                id: saveLayoutProc
                running: false
            }

            function applyLayout(items) {
                togglesModel.clear()
                for (let i = 0; i < items.length; i++) {
                    togglesModel.append(items[i])
                }
            }

            Timer {
                id: morphStartTimer
                interval: 20
                onTriggered: {
                    expandedCard.animationsEnabled = true
                    expandedLoader.sourceComponent = expandedOverlay.widgetItem.expandedComponent
                    expandedOverlay.open()
                }
            }

            function openExpandedView(sourceRect, widgetItem) {
                let pos = sourceRect.mapToItem(controlPanel, 0, 0)
                expandedOverlay.sourceItem = sourceRect
                expandedOverlay.widgetItem = widgetItem
                expandedOverlay.startX = pos.x
                expandedOverlay.startY = pos.y
                expandedOverlay.startWidth = sourceRect.width
                expandedOverlay.startHeight = sourceRect.height
                
                // Disable animations to instantly snap to the source toggle
                expandedCard.animationsEnabled = false
                expandedCard.x = expandedOverlay.startX
                expandedCard.y = expandedOverlay.startY
                expandedCard.width = expandedOverlay.startWidth
                expandedCard.height = expandedOverlay.startHeight
                expandedCard.radius = (expandedOverlay.startWidth === expandedOverlay.startHeight) ? expandedOverlay.startWidth / 2 : 24
                
                // Use a Timer to ensure QML engine commits the geometry snap before re-enabling animations
                morphStartTimer.start()
            }

            function closeExpandedView() {
                expandedOverlay.close()
            }

            function saveLayout() {
                let items = []
                for (let i = 0; i < togglesModel.count; i++) {
                    let item = togglesModel.get(i)
                    items.push({
                        source: item.source,
                        colSpan: item.colSpan,
                        rowSpan: item.rowSpan
                    })
                }
                let path = Qt.resolvedUrl("../config/control_center_layout.json").toString().replace("file://", "")
                controlPanel.ignoreNextChange = true
                saveLayoutProc.command = ["sh", "-c", "echo \"$1\" > \"$2\"", "sh", JSON.stringify(items, null, 2), path]
                saveLayoutProc.running = true
            }

            function resetLayout() {
                applyLayout(defaultLayout)
                saveLayout()
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

                    // ── Status Icons Morph ──
                    Row {
                        id: morphStatusIcons
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        spacing: 12

                        // 1. Tray Icons
                        Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Repeater {
                                model: SystemTray.items
                                delegate: Item {
                                    width: 20; height: 20
                                    Image {
                                        id: trayIconMorph
                                        anchors.fill: parent
                                        sourceSize: Qt.size(24, 24)
                                        source: modelData.icon
                                        visible: false
                                    }
                                    ColorOverlay {
                                        anchors.fill: trayIconMorph
                                        source: trayIconMorph
                                        color: "white"
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
                                source: shellRoot.icon(shellRoot.bluetoothEnabled ? "network-bluetooth" : "bluetooth-disabled-symbolic")
                                sourceSize: Qt.size(24, 24)
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: btIconMorph
                                source: btIconMorph
                                color: "white"
                            }
                        }

                        // WiFi
                        Item {
                            width: (shellRoot.wifiEnabled && shellRoot.wifiConnected) ? 20 : 0
                            height: 20
                            visible: width > 0
                            anchors.verticalCenter: parent.verticalCenter
                            Image {
                                id: wifiIconMorph
                                anchors.fill: parent
                                source: {
                                    if (!shellRoot.wifiEnabled) return shellRoot.icon("network-wireless-offline-symbolic");
                                    if (!shellRoot.wifiConnected) return shellRoot.icon("network-disconnect-symbolic");
                                    let levels = ["none", "weak", "ok", "good", "excellent"];
                                    let level = levels[shellRoot.wifiSignalLevel] || "none";
                                    return shellRoot.icon("network-wireless-signal-" + level + "-symbolic");
                                }
                                sourceSize: Qt.size(24, 24)
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: wifiIconMorph
                                source: wifiIconMorph
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
                                    id: battIconMorph
                                    anchors.fill: parent
                                    source: {
                                        let isCharging = qs.batteryStatus === "Charging"
                                        let pct = qs.batteryPct
                                        if (pct < 0) return shellRoot.icon("battery-missing-symbolic")
                                        let level = Math.max(0, Math.min(100, Math.round(pct / 10) * 10))
                                        let sLevel = (level < 100 ? (level < 10 ? "00" : "0") : "") + level
                                        let name = "battery-" + sLevel
                                        if (isCharging) name += "-charging"
                                        name += "-symbolic"
                                        return shellRoot.icon(name)
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
                        width: 60; height: 28; radius: 14
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
                                    controlPanel.saveLayout()
                                }
                                controlPanel.editMode = !controlPanel.editMode
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

                    GridLayout {
                        id: toggleGrid
                        Layout.fillWidth: true
                        columns: 4
                        rowSpacing: 16
                        columnSpacing: 16

                        Repeater {
                        model: togglesModel
                        delegate: Item {
                            id: delegateItem
                            property int itemIndex: index
                            property bool isDragging: controlPanel.dragIndex === index
                            property real savedWidth: 0
                            property real savedHeight: 0

                            // Keep the layout slot full size so it acts as a placeholder
                            Layout.columnSpan: model.colSpan
                            Layout.rowSpan: model.rowSpan
                            Layout.fillWidth: true
                            Layout.preferredHeight: (model.rowSpan * ((400 - 48 - 48) / 4)) + ((model.rowSpan - 1) * 16)


                            Behavior on x { enabled: !widgetOverlay.dragActive; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on y { enabled: !widgetOverlay.dragActive; NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }

                            Timer {
                                id: moveThrottle
                                interval: 150
                            }

                            DropArea {
                                anchors.fill: parent
                                keys: ["toggle"]
                                enabled: controlPanel.editMode && !delegateItem.isDragging
                                onEntered: (drag) => {
                                    if (!moveThrottle.running && drag.source.itemIndex !== delegateItem.itemIndex) {
                                        let targetIdx = delegateItem.itemIndex
                                        togglesModel.move(drag.source.itemIndex, targetIdx, 1)
                                        controlPanel.dragIndex = targetIdx
                                        moveThrottle.start()
                                    }
                                }
                            }

                            Rectangle {
                                id: widgetBg
                                property bool isCircle: model.colSpan === 1 && model.rowSpan === 1
                                width: isCircle ? Math.min(parent.width, parent.height) : parent.width
                                height: isCircle ? width : parent.height
                                x: (parent.width - width) / 2
                                y: (parent.height - height) / 2
                                radius: (model.colSpan >= 2 && model.rowSpan >= 2) ? 24 : Math.min(width, height) / 2
                                color: Qt.rgba(0.15, 0.15, 0.2, 0.8)
                                clip: true

                                property bool isItemPressed: {
                                    if (controlPanel.editMode) return false;
                                    if (widgetLoader.item && widgetLoader.item.isSimpleToggle) return simpleToggleMouse.pressed;
                                    if (widgetLoader.item && "isPressed" in widgetLoader.item) return widgetLoader.item.isPressed;
                                    return complexHoldArea.pressed;
                                }

                                scale: widgetOverlay.dragActive ? 1.05 : (isItemPressed ? 0.95 : 1.0)
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                layer.enabled: true
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
                                        controlPanel.openExpandedView(widgetBg, widgetLoader.item)
                                    }
                                }

                                Loader {
                                    id: widgetLoader
                                    anchors.fill: parent
                                    property var modelData: model
                                    source: model.source || ""
                                    onLoaded: {
                                        // Connect expandRequested signal for widgets that handle their own hold detection
                                        if (item && item.expandRequested) {
                                            item.expandRequested.connect(function() {
                                                if (!controlPanel.editMode && item.hasExpandedView) {
                                                    controlPanel.openExpandedView(widgetBg, item)
                                                }
                                            })
                                        }
                                    }
                                }

                                // ── Shell-provided toggle chrome for simple toggles ──
                                // If the loaded widget has `isSimpleToggle: true`, the shell
                                // handles all styling (active bg, icon, label, click).
                                Rectangle {
                                    id: toggleChrome
                                    anchors.fill: parent
                                    visible: widgetLoader.item && widgetLoader.item.isSimpleToggle === true
                                    radius: widgetBg.radius
                                    color: {
                                        if (!widgetLoader.item || !widgetLoader.item.isSimpleToggle) return "transparent"
                                        if (model.colSpan === 2 && model.rowSpan === 2) return "transparent"
                                        let w = widgetLoader.item
                                        return w.isActive ? (w.activeColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)) : "transparent"
                                    }
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    // ── Layout for non-2x2 toggles (1x1 circles, 2x1 pills) ──
                                    GridLayout {
                                        visible: !(model.colSpan === 2 && model.rowSpan === 2)
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: model.colSpan > model.rowSpan ? (parent.height / 2 - 16) : 8
                                        width: model.colSpan > model.rowSpan ? (parent.width - x - 16) : (parent.width - 16)

                                        columns: model.colSpan > model.rowSpan ? 2 : 1
                                        rowSpacing: 8
                                        columnSpacing: 12

                                        Image {
                                            Layout.alignment: Qt.AlignCenter
                                            width: (model.colSpan === 1 && model.rowSpan === 1) ? 24 : 32
                                            height: width
                                            sourceSize: Qt.size(width, width)
                                            source: (widgetLoader.item && widgetLoader.item.iconSource) || ""
                                        }

                                        ColumnLayout {
                                            visible: model.colSpan > 1
                                            Layout.alignment: model.colSpan > model.rowSpan ? Qt.AlignVCenter | Qt.AlignLeft : Qt.AlignHCenter
                                            Layout.fillWidth: model.colSpan > model.rowSpan
                                            spacing: 0

                                            Text {
                                                text: (widgetLoader.item && widgetLoader.item.titleText) || ""
                                                color: "white"
                                                font.pixelSize: 14
                                                font.bold: true
                                                Layout.fillWidth: true
                                                horizontalAlignment: model.colSpan > model.rowSpan ? Text.AlignLeft : Text.AlignHCenter
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: (widgetLoader.item && widgetLoader.item.subtitleText) || ""
                                                visible: text !== ""
                                                color: Qt.rgba(1, 1, 1, 0.6)
                                                font.pixelSize: 12
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
                                            width: 48; height: 48; radius: 24
                                            anchors.top: parent.top; anchors.topMargin: 16
                                            anchors.left: parent.left; anchors.leftMargin: 16
                                            color: {
                                                if (!widgetLoader.item || !widgetLoader.item.isSimpleToggle) return Qt.rgba(1, 1, 1, 0.1)
                                                let w = widgetLoader.item
                                                return w.isActive ? (w.activeColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)) : Qt.rgba(1, 1, 1, 0.1)
                                            }
                                            Behavior on color { ColorAnimation { duration: 200 } }

                                            Image {
                                                anchors.centerIn: parent
                                                width: 24; height: 24
                                                sourceSize: Qt.size(24, 24)
                                                source: (widgetLoader.item && widgetLoader.item.iconSource) || ""
                                            }
                                        }

                                        ColumnLayout {
                                            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
                                            anchors.left: parent.left; anchors.leftMargin: 16
                                            anchors.right: parent.right; anchors.rightMargin: 16
                                            spacing: 0

                                            Text {
                                                text: (widgetLoader.item && widgetLoader.item.titleText) || ""
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
                                                font.pixelSize: 12
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
                                        onClicked: {
                                            if (widgetLoader.item && widgetLoader.item.toggled)
                                                widgetLoader.item.toggled()
                                        }
                                        onPressAndHold: {
                                            if (widgetLoader.item && widgetLoader.item.hasExpandedView) {
                                                controlPanel.openExpandedView(widgetBg, widgetLoader.item)
                                            }
                                        }
                                    }
                                }

                                EditOverlay {
                                    id: widgetOverlay
                                    anchors.fill: parent
                                    editMode: controlPanel.editMode
                                    itemIndex: delegateItem.itemIndex
                                    widgetSource: model.source || ""
                                    currentColSpan: model.colSpan
                                    currentRowSpan: model.rowSpan
                                    availableSizes: widgetLoader.item ? widgetLoader.item.availableSizes : undefined

                                    Drag.source: delegateItem

                                    onDragStarted: {
                                        // Save dimensions before the slot collapses
                                        delegateItem.savedWidth = widgetBg.width
                                        delegateItem.savedHeight = widgetBg.height

                                        // Reparent to flickable to escape GridLayout management
                                        let pos = widgetBg.mapToItem(toggleFlickable.contentItem, 0, 0)
                                        widgetBg.parent = toggleFlickable.contentItem
                                        widgetBg.x = pos.x
                                        widgetBg.y = pos.y
                                        widgetBg.width = delegateItem.savedWidth
                                        widgetBg.height = delegateItem.savedHeight

                                        controlPanel.dragIndex = delegateItem.itemIndex
                                        widgetBg.z = 100
                                    }
                                    onDragFinished: {
                                        controlPanel.dragIndex = -1

                                        // Reparent back to delegate and restore bindings
                                        widgetBg.parent = delegateItem
                                        widgetBg.z = 0
                                        widgetBg.x = Qt.binding(() => (delegateItem.width - widgetBg.width) / 2)
                                        widgetBg.y = Qt.binding(() => (delegateItem.height - widgetBg.height) / 2)
                                        widgetBg.width = Qt.binding(() => widgetBg.isCircle ? Math.min(delegateItem.width, delegateItem.height) : delegateItem.width)
                                        widgetBg.height = Qt.binding(() => widgetBg.isCircle ? widgetBg.width : delegateItem.height)
                                    }
                                    onRemoved: {
                                        togglesModel.remove(index)
                                    }
                                    onResized: (newColSpan, newRowSpan) => {
                                        togglesModel.setProperty(index, "colSpan", newColSpan)
                                        togglesModel.setProperty(index, "rowSpan", newRowSpan)
                                    }
                                }
                            }
                        }
                    } // closes Repeater
                    } // closes GridLayout

                    // ── Add a Control Button (iOS 18 style) ──
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 48
                        width: 160; height: 36; radius: 18
                        color: Qt.rgba(0.15, 0.15, 0.2, 0.8)
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                        visible: controlPanel.editMode

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {
                                width: 16; height: 16; radius: 8
                                color: "transparent"
                                border.color: "white"
                                border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle {
                                    width: 8; height: 2; radius: 1
                                    color: "white"
                                    anchors.centerIn: parent
                                }
                                Rectangle {
                                    width: 2; height: 8; radius: 1
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
                                addControlPopup.open()
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
                nameFilters: ["*Toggle.qml", "*Slider.qml", "*Widget.qml"]
                showDirs: false
            }

            Rectangle {
                id: addControlPopup
                anchors.fill: parent
                radius: 28
                color: Qt.rgba(0.1, 0.1, 0.15, 0.95)
                visible: opacity > 0
                opacity: 0
                z: 100
                scale: opacity > 0.5 ? 1.0 : 0.9

                Behavior on opacity { NumberAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                function open() { opacity = 1.0 }
                function close() { opacity = 0.0 }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

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
                            width: 32; height: 32; radius: 16
                            color: Qt.rgba(1, 1, 1, 0.1)
                            Image {
                                anchors.centerIn: parent
                                width: 16; height: 16
                                sourceSize: Qt.size(24, 24)
                                source: shellRoot.icon("window-close-symbolic")
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: addControlPopup.close()
                            }
                        }
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: togglesFolderModel
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 56
                            radius: 16
                            color: addArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Loader {
                                    id: previewLoader
                                    source: Qt.resolvedUrl("toggles/" + model.fileName)
                                    asynchronous: true
                                    visible: false // We just want its properties
                                }

                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    Image {
                                        anchors.centerIn: parent
                                        source: (previewLoader.item && previewLoader.item.iconSource) ? previewLoader.item.iconSource : (shellRoot.icon("list-add-symbolic") || "")
                                        sourceSize: Qt.size(16, 16)
                                    }
                                }

                                Text {
                                    text: (previewLoader.item && previewLoader.item.titleText) ? previewLoader.item.titleText : model.fileName.replace(".qml", "")
                                    color: "white"
                                    font.pixelSize: 16
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: addArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    let sourcePath = "toggles/" + model.fileName
                                    // Default spans
                                    let cSpan = 1
                                    let rSpan = 1
                                    if (sourcePath.indexOf("Slider") !== -1) { cSpan = 2; rSpan = 1; }
                                    if (sourcePath.indexOf("Media") !== -1) { cSpan = 2; rSpan = 2; }
                                    if (sourcePath.indexOf("Wifi") !== -1 || sourcePath.indexOf("Bluetooth") !== -1 || sourcePath.indexOf("PowerProfile") !== -1) { cSpan = 2; rSpan = 1; }

                                    togglesModel.append({ source: sourcePath, colSpan: cSpan, rowSpan: rSpan })
                                    addControlPopup.close()
                                }
                            }
                        }
                    }
                }
            }


            // ── Expanded View Overlay ──
            Item {
                id: expandedOverlay
                anchors.fill: parent
                visible: opacity > 0
                opacity: 0
                z: 200

                property var sourceItem: null
                property var widgetItem: null
                property real startX: 0
                property real startY: 0
                property real startWidth: 0
                property real startHeight: 0
                property bool isExpanded: false

                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }


                function open() {
                    isExpanded = true
                    opacity = 1.0

                    expandedLoader.sourceComponent = widgetItem.expandedComponent

                    // Use bindings so that if implicitHeight changes after loading, the card resizes dynamically
                    expandedCard.width = Qt.binding(function() { return expandedOverlay.width })
                    expandedCard.height = Qt.binding(function() {
                        let contentH = expandedLoader.item && expandedLoader.item.implicitHeight > 0 
                                          ? expandedLoader.item.implicitHeight 
                                          : 0;
                        return contentH > 0 
                                  ? contentH + 48 // 24 margins top/bottom
                                  : ((widgetItem && widgetItem.expandedHeight) ? widgetItem.expandedHeight : 420);
                    })
                    expandedCard.x = Qt.binding(function() { return 0 })
                    expandedCard.y = Qt.binding(function() { return (expandedOverlay.height - expandedCard.height) / 2 })
                    expandedCard.radius = 36
                }

                function close() {
                    isExpanded = false
                    opacity = 0.0
                    // Morph back to original slot
                    expandedCard.x = startX
                    expandedCard.y = startY
                    expandedCard.width = startWidth
                    expandedCard.height = startHeight
                    expandedCard.radius = (startWidth === startHeight) ? startWidth / 2 : 24
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: expandedOverlay.close()
                }

                Rectangle {
                    id: expandedCard
                    property bool animationsEnabled: true
                    color: Qt.rgba(0.15, 0.15, 0.2, 0.95)
                    clip: true
                    
                    Behavior on x { enabled: expandedCard.animationsEnabled; NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    Behavior on y { enabled: expandedCard.animationsEnabled; NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    Behavior on width { enabled: expandedCard.animationsEnabled; NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    Behavior on height { enabled: expandedCard.animationsEnabled; NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    Behavior on radius { enabled: expandedCard.animationsEnabled; NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                    // Only show loader content when fully expanded to avoid layout jumping during morph
                    Loader {
                        id: expandedLoader
                        anchors.fill: parent
                        anchors.margins: 24
                        focus: true
                        opacity: expandedOverlay.isExpanded ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }
            }
        } // closes controlPanel


        // Hide after close animation
        Timer {
            id: hideTimer
            interval: 400
            running: !qs.isOpen
            onTriggered: qs.visible = false
        }
    }
}
