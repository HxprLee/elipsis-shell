import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

    Process { id: wifiToggle; running: false }
    Process { id: btToggle; running: false }

    function toggleWifi() {
        wifiToggle.command = ["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]
        wifiToggle.running = true
        // Predict the state instantly while waiting for the global timer to catch up
        shellRoot.wifiEnabled = !wifiEnabled
    }
    function toggleBluetooth() {
        btToggle.command = ["bluetoothctl", "power", bluetoothEnabled ? "off" : "on"]
        btToggle.running = true
        shellRoot.bluetoothEnabled = !bluetoothEnabled
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
            panelContainer.y = 10
            panelContainer.bloomScale = 0.85
            panelContainer.opacity = 0.0
            bgDim.opacity = 0.0
        }
    }

    // ── Background dim ──
    Rectangle {
        id: bgDim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.3)
        opacity: 0
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
                    shellRoot.panelOpen = false
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
            height: 600
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
                anchors.bottom: parent.bottom
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
        Rectangle {
            id: controlPanel
            anchors.right: parent.right
            anchors.rightMargin: 24
            width: 400
            height: 460
            radius: 28
            color: "transparent"
            transformOrigin: Item.TopRight
            scale: panelContainer.bloomScale

            // ── Status Icons Morph ──
            Row {
                id: morphStatusIcons
                anchors.top: parent.top
                anchors.topMargin: 12 + (12 * (1 - progress)) // Transition from status bar top
                anchors.right: parent.right
                anchors.rightMargin: 24 + (16 - 24) * (1 - progress) // Transition from status bar right
                spacing: 12
                opacity: progress

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

            // ── Quick toggles grid ──
            GridLayout {
                id: toggleGrid
                opacity: progress // Non-morphing content fades in
                anchors.top: morphStatusIcons.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 12 // Reduced from 24 to fit icons above
                columns: 4
                rowSpacing: 24
                columnSpacing: 24

                // WiFi
                Column {
                    Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                    Rectangle {
                        width: 64; height: 64; radius: 32
                        color: qs.wifiEnabled ? Qt.rgba(0.2, 0.5, 1.0, 1.0) : Qt.rgba(0.15, 0.15, 0.2, 0.8)
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Image {
                            anchors.centerIn: parent
                            width: 24; height: 24
                            sourceSize: Qt.size(24, 24)
                            source: shellRoot.icon(qs.wifiEnabled ? "network-wireless-symbolic" : "network-wireless-offline-symbolic")
                        }
                        MouseArea { anchors.fill: parent; onClicked: qs.toggleWifi() }
                    }
                }

                // Bluetooth
                Column {
                    Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                    Rectangle {
                        width: 64; height: 64; radius: 32
                        color: qs.bluetoothEnabled ? Qt.rgba(0.2, 0.5, 1.0, 1.0) : Qt.rgba(0.15, 0.15, 0.2, 0.8)
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Image {
                            anchors.centerIn: parent
                            width: 24; height: 24
                            sourceSize: Qt.size(24, 24)
                            source: shellRoot.icon(qs.bluetoothEnabled ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic")
                        }
                        MouseArea { anchors.fill: parent; onClicked: qs.toggleBluetooth() }
                    }
                }

                // Settings
                Column {
                    Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                    Rectangle {
                        width: 64; height: 64; radius: 32
                        color: Qt.rgba(0.15, 0.15, 0.2, 0.8)
                        anchors.horizontalCenter: parent.horizontalCenter
                        Image { anchors.centerIn: parent; width: 24; height: 24; sourceSize: Qt.size(24, 24); source: shellRoot.icon("preferences-system-symbolic") }
                    }
                }

                // Lock
                Column {
                    Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                    Rectangle {
                        width: 64; height: 64; radius: 32
                        color: Qt.rgba(0.15, 0.15, 0.2, 0.8)
                        anchors.horizontalCenter: parent.horizontalCenter
                        Image { anchors.centerIn: parent; width: 24; height: 24; sourceSize: Qt.size(24, 24); source: shellRoot.icon("system-lock-screen-symbolic") }
                        MouseArea { anchors.fill: parent; onClicked: { shellRoot.lock(); shellRoot.panelOpen = false; } }
                    }
                }

                // Power
                Column {
                    Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                    Rectangle {
                        width: 64; height: 64; radius: 32
                        color: Qt.rgba(0.15, 0.15, 0.2, 0.8)
                        anchors.horizontalCenter: parent.horizontalCenter
                        Image { anchors.centerIn: parent; width: 24; height: 24; sourceSize: Qt.size(24, 24); source: shellRoot.icon("system-shutdown-symbolic") }
                    }
                }
            }

            // ── Sliders ──
            Column {
                opacity: progress // Non-morphing content fades in
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 24
                width: toggleGrid.width
                spacing: 16

                // Brightness
                Slider {
                    id: brightnessSlider
                    width: parent.width; height: 48
                    from: 0; to: 100
                    value: qs.brightnessValue
                    onMoved: qs.setBrightness(value)

                    background: Rectangle {
                        x: brightnessSlider.leftPadding
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                        implicitWidth: parent.width; implicitHeight: 48
                        width: brightnessSlider.availableWidth; height: implicitHeight; radius: 24
                        color: Qt.rgba(0.2, 0.2, 0.25, 0.8)
                        Rectangle {
                            width: brightnessSlider.visualPosition * (parent.width - height) + height
                            height: parent.height; color: Qt.rgba(0.2, 0.5, 1.0, 1.0); radius: 24
                        }
                    }
                    handle: Rectangle {
                        x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
                        y: brightnessSlider.topPadding + brightnessSlider.availableHeight / 2 - height / 2
                        implicitWidth: 48; implicitHeight: 48; radius: 24; color: "white"
                        Image {
                            anchors.centerIn: parent
                            width: 22; height: 22
                            sourceSize: Qt.size(24, 24)
                            source: shellRoot.icon("display-brightness-symbolic")
                        }
                    }
                }

                // Volume
                Slider {
                    id: volumeSlider
                    width: parent.width; height: 48
                    from: 0; to: 100
                    value: qs.audioNode ? qs.audioNode.volume * 100 : 50
                    onMoved: { if (qs.audioNode) qs.audioNode.volume = value / 100.0 }

                    background: Rectangle {
                        x: volumeSlider.leftPadding
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        implicitWidth: parent.width; implicitHeight: 48
                        width: volumeSlider.availableWidth; height: implicitHeight; radius: 24
                        color: Qt.rgba(0.2, 0.2, 0.25, 0.8)
                        Rectangle {
                            width: volumeSlider.visualPosition * (parent.width - height) + height
                            height: parent.height; color: Qt.rgba(0.2, 0.5, 1.0, 1.0); radius: 24
                        }
                    }
                    handle: Rectangle {
                        x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                        y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                        implicitWidth: 48; implicitHeight: 48; radius: 24; color: "white"
                        Image {
                            anchors.centerIn: parent
                            width: 22; height: 22
                            sourceSize: Qt.size(24, 24)
                            source: shellRoot.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                        }
                    }
                }
            }
        }

        // Hide after close animation
        Timer {
            id: hideTimer
            interval: 400
            running: !qs.isOpen
            onTriggered: qs.visible = false
        }
    }
}
