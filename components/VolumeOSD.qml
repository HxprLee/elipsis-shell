import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: osd
    visible: false
    color: "transparent"

    anchors {
        top: true
        left: true
        right: true
        bottom: mediaWidgetOpen || mediaWidgetAnimating
    }

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrLayershell.None

    implicitHeight: (mediaWidgetOpen || mediaWidgetAnimating) ? (osd.screen ? osd.screen.height : 1080) : 120
    margins.top: 50

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    property real volume: audioNode ? audioNode.volume : 0
    property bool muted: audioNode ? audioNode.muted : false
    property bool isSlim: false
    property bool isInteracting: false
    property bool isInitialized: false
    property bool _userExpanded: false

    property bool mediaWidgetOpen: false
    property bool mediaWidgetAnimating: false

    onMediaWidgetOpenChanged: {
        if (mediaWidgetOpen) {
            mediaWidgetAnimating = true
            animTimer.stop()
        } else {
            animTimer.restart()
        }
    }

    Timer {
        id: animTimer
        interval: 410
        onTriggered: osd.mediaWidgetAnimating = false
    }
    property var _manualPlayer: null
    property var activePlayer: {
        let players = Mpris.players.values
        if (players.length === 0) {
            _manualPlayer = null
            return null
        }
        if (_manualPlayer && players.indexOf(_manualPlayer) !== -1) {
            return _manualPlayer
        }
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) {
                _manualPlayer = null
                return players[i]
            }
        }
        return players[0]
    }

    function cyclePlayer() {
        let players = Mpris.players.values
        if (players.length <= 1) return
        let idx = players.indexOf(activePlayer)
        if (idx === -1) idx = 0
        _manualPlayer = players[(idx + 1) % players.length]
    }

    onVolumeChanged: {
        if (!isInitialized || shellRoot.panelOpen) return;
        showOSD()
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00";
        let mins = Math.floor(seconds / 60);
        let secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    function getAppIcon(player) {
        if (!player) return "";
        const apps = DesktopEntries.applications.values;
        const identity = player.identity.toLowerCase();
        const desktopId = player.desktopEntry ? player.desktopEntry.toLowerCase() : "";

        if (desktopId) {
            const app = apps.find(a => a.id.toLowerCase() === desktopId || a.id.toLowerCase() === desktopId + ".desktop");
            if (app && app.icon) return app.icon.startsWith("/") ? "file://" + app.icon : "image://icon/" + app.icon;
        }

        const app = apps.find(a => a.name.toLowerCase() === identity || a.id.toLowerCase().includes(identity));
        if (app && app.icon) return app.icon.startsWith("/") ? "file://" + app.icon : "image://icon/" + app.icon;

        return "";
    }
    
    onMutedChanged: {
        if (!isInitialized || shellRoot.panelOpen) return;
        showOSD()
    }

    Component.onCompleted: {
        startupTimer.start()
    }

    Timer {
        id: startupTimer
        interval: 1000
        onTriggered: osd.isInitialized = true
    }

    Timer {
        id: expandCooldownTimer
        interval: 100
        onTriggered: osd._userExpanded = false
    }

    function showOSD() {
        if (!osd.visible || hideAnim.running) {
            osd.visible = true
            isSlim = false
            hideAnim.stop()
            showAnim.restart()
        } else if (!isInteracting && !mediaWidgetOpen && !_userExpanded) {
            isSlim = true
        }
        if (!mediaWidgetOpen) hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: {
            if (!osd.mediaWidgetOpen) hideAnim.start()
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: layoutContainer; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { target: layoutContainer; property: "scale"; from: 0.8; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        NumberAnimation { target: layoutContainer; property: "y"; from: -20; to: 0; duration: 400; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation { target: layoutContainer; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InCubic }
        NumberAnimation { target: layoutContainer; property: "scale"; to: 0.9; duration: 300; easing.type: Easing.InCubic }
        onFinished: {
            osd.visible = false
            osd.isSlim = false
            osd.isInteracting = false
            osd._userExpanded = false
            osd.mediaWidgetOpen = false
        }
    }

    // Dismissal MouseArea
    MouseArea {
        anchors.fill: parent
        enabled: osd.mediaWidgetOpen || osd.mediaWidgetAnimating
        onClicked: {
            if (osd.mediaWidgetOpen) {
                osd.mediaWidgetOpen = false
                hideTimer.restart()
            }
        }
    }

    Item {
        id: layoutContainer
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: mainRow.implicitWidth
        height: mainRow.implicitHeight

        opacity: 0
        scale: 0.8

        RowLayout {
            id: mainRow
            spacing: 12

            // --- The iOS Style Pill ---
            Rectangle {
                id: content
                Layout.alignment: Qt.AlignTop
                width: 220
                Layout.preferredHeight: isSlim ? 8 : 48
                radius: height / 2
                color: "transparent"

                MaterialSurface {
                    anchors.fill: parent
                    radius: parent.radius
                }

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: content.width
                        height: content.height
                        radius: content.radius
                    }
                }

                Rectangle {
                    id: progressFill
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * osd.volume
                    color: "white"
                    opacity: osd.muted ? 0.4 : 0.9
                    
                    Behavior on width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: osd.visible
                    
                    function handleVolume(mouse) {
                        if (osd.audioNode) {
                            osd.isInteracting = true
                            let ratio = (parent.width - mouse.x) / parent.width
                            osd.audioNode.volume = Math.max(0, Math.min(1, ratio))
                            hideTimer.restart()
                        }
                    }

                    onPressed: (mouse) => {
                        if (osd.isSlim) osd._userExpanded = true
                        osd.isSlim = false
                        handleVolume(mouse)
                    }
                    onPositionChanged: (mouse) => handleVolume(mouse)
                    onReleased: {
                        osd.isInteracting = false
                        expandCooldownTimer.restart()
                        hideTimer.restart()
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 8
                    opacity: isSlim ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    Text {
                        text: Math.round(osd.volume * 100)
                        color: (progressFill.width > 185) ? "#111" : "white"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Item { Layout.fillWidth: true }

                    Item {
                        width: 20; height: 20
                        Image {
                            id: volIcon
                            anchors.fill: parent
                            sourceSize: Qt.size(24, 24)
                            source: shellRoot.icon(osd.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: volIcon
                            source: volIcon
                            color: (progressFill.width > 30) ? "#111" : "white" 
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                }
            }

            // --- The Circle Button Spacer ---
            Item {
                id: circleButtonContainer
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: (osd.activePlayer && !osd.isSlim) ? 48 : 0
                height: 48
                clip: true

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                }
            }
        }
        
        // --- The Expanded Media Widget ---
        Rectangle {
            id: mediaWidget
            // Morphing geometry
            x: osd.mediaWidgetOpen ? (layoutContainer.width / 2 - 170) : (circleButtonContainer.x)
            y: osd.mediaWidgetOpen ? 64 : circleButtonContainer.y
            width: osd.mediaWidgetOpen ? 340 : 48
            height: osd.mediaWidgetOpen ? 160 : 48
            radius: osd.mediaWidgetOpen ? 20 : 24
            
            opacity: 1
            visible: osd.activePlayer && !osd.isSlim
            
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: 1
            clip: true
            
            Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
            Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: mediaWidget.width
                    height: mediaWidget.height
                    radius: mediaWidget.radius
                }
            }

            // Click to open
            MouseArea {
                anchors.fill: parent
                enabled: !osd.mediaWidgetOpen
                onClicked: osd.mediaWidgetOpen = true
            }

            // Circular Progress Bar (visible when closed)
            Canvas {
                id: progressCanvas
                anchors.fill: parent
                opacity: osd.mediaWidgetOpen ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 300 } }

                property real progress: {
                    if (!osd.activePlayer || !osd.activePlayer.lengthSupported || osd.activePlayer.length <= 0) return 0;
                    return Math.max(0, Math.min(1.0, osd.activePlayer.position / osd.activePlayer.length));
                }

                onProgressChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var x = width / 2;
                    var y = height / 2;
                    var radius = width / 2 - 1.5; // 1.5px padding for stroke

                    // Background track
                    ctx.beginPath();
                    ctx.arc(x, y, radius, 0, 2 * Math.PI);
                    ctx.lineWidth = 3;
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.15)";
                    ctx.stroke();

                    if (progress > 0) {
                        ctx.beginPath();
                        ctx.arc(x, y, radius, -0.5 * Math.PI, (2 * Math.PI * progress) - 0.5 * Math.PI);
                        ctx.lineWidth = 3;
                        ctx.strokeStyle = "rgba(255, 255, 255, 1.0)";
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }
            }

            // Sharp Image (visible when closed)
            Rectangle {
                anchors.centerIn: parent
                width: osd.mediaWidgetOpen ? mediaWidget.width : 42
                height: osd.mediaWidgetOpen ? mediaWidget.height : 42
                radius: osd.mediaWidgetOpen ? mediaWidget.radius : 21
                color: "transparent"

                Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                Behavior on radius { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                Image {
                    id: sharpImage
                    anchors.fill: parent
                    source: osd.activePlayer && osd.activePlayer.trackArtUrl ? osd.activePlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    opacity: osd.mediaWidgetOpen ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: sharpImage.width
                            height: sharpImage.height
                            radius: osd.mediaWidgetOpen ? mediaWidget.radius : 21
                        }
                    }
                }
            }

            // Blurred Background (visible when open)
            Item {
                anchors.centerIn: parent
                width: 340
                height: 160
                opacity: osd.mediaWidgetOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }

                Image {
                    id: mediaBg
                    anchors.fill: parent
                    source: osd.activePlayer && osd.activePlayer.trackArtUrl ? osd.activePlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                FastBlur {
                    anchors.fill: parent
                    source: mediaBg
                    radius: 40
                    cached: true
                }
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.4) // Darken overlay
                }
            }

            // Widget Content (fades in)
            Item {
                anchors.fill: parent
                opacity: osd.mediaWidgetOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InQuad } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: parent.height
                        Layout.preferredHeight: parent.height
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.1)

                        Image {
                            id: expandedArt
                            anchors.fill: parent
                            source: osd.activePlayer && osd.activePlayer.trackArtUrl ? osd.activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: expandedArt.width; height: expandedArt.height; radius: 8
                                }
                            }
                        }
                    }

                    // Right: Content
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        // Top row: Text + App Icon
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: osd.activePlayer ? (osd.activePlayer.trackTitle || "Unknown Title") : "No Media"
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: osd.activePlayer && osd.activePlayer.trackArtists ? (Array.isArray(osd.activePlayer.trackArtists) ? osd.activePlayer.trackArtists.join(', ') : osd.activePlayer.trackArtists) : "Unknown Artist"
                                    color: Qt.rgba(1, 1, 1, 0.7)
                                    font.pixelSize: 13
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: osd.activePlayer !== null
                                }
                            }

                            // Player app icon
                            Rectangle {
                                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: 12
                                color: Qt.rgba(1, 1, 1, 0.1)
                                visible: osd.activePlayer !== null

                                Image {
                                    id: appIcon4x2
                                    anchors.centerIn: parent
                                    source: osd.getAppIcon(osd.activePlayer)
                                    sourceSize: Qt.size(14, 14)
                                    fillMode: Image.PreserveAspectFit
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: osd.cyclePlayer()
                                }
                            }
                        }

                        Item { Layout.fillHeight: true } // Spacer

                        // Middle row: Transport Controls
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Item { Layout.fillWidth: true } // Push left

                            RowLayout {
                                spacing: 24

                                // Previous
                                Item {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    opacity: osd.activePlayer && (osd.activePlayer.canGoPrevious ?? false) ? 1.0 : 0.4
                                    Image {
                                        id: skipBackIcon
                                        anchors.fill: parent
                                        source: shellRoot.icon("media-skip-backward-symbolic")
                                        sourceSize: Qt.size(24, 24)
                                        visible: false
                                    }
                                    ColorOverlay {
                                        anchors.fill: skipBackIcon
                                        source: skipBackIcon
                                        color: "white"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        onClicked: if(osd.activePlayer) osd.activePlayer.previous()
                                    }
                                }

                                // Play/Pause
                                Item {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    opacity: osd.activePlayer && (osd.activePlayer.canTogglePlaying ?? false) ? 1.0 : 0.4
                                    Image {
                                        id: playIcon
                                        anchors.fill: parent
                                        source: shellRoot.icon(osd.activePlayer && osd.activePlayer.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                                        sourceSize: Qt.size(32, 32)
                                        visible: false
                                    }
                                    ColorOverlay {
                                        anchors.fill: playIcon
                                        source: playIcon
                                        color: "white"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -12
                                        onClicked: if(osd.activePlayer) osd.activePlayer.togglePlaying()
                                    }
                                }

                                // Next
                                Item {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    opacity: osd.activePlayer && (osd.activePlayer.canGoNext ?? false) ? 1.0 : 0.4
                                    Image {
                                        id: skipFwdIcon
                                        anchors.fill: parent
                                        source: shellRoot.icon("media-skip-forward-symbolic")
                                        sourceSize: Qt.size(24, 24)
                                        visible: false
                                    }
                                    ColorOverlay {
                                        anchors.fill: skipFwdIcon
                                        source: skipFwdIcon
                                        color: "white"
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        onClicked: if(osd.activePlayer) osd.activePlayer.next()
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true } // Push right
                        }

                        Item { Layout.fillHeight: true } // Spacer

                        // Bottom row: Progress Bar
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: osd.activePlayer !== null

                            Item {
                                Layout.fillWidth: true
                                height: 4

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.15)
                                }

                                Rectangle {
                                    width: {
                                        if (!osd.activePlayer || !osd.activePlayer.lengthSupported || osd.activePlayer.length <= 0) return 0;
                                        return Math.min(1.0, osd.activePlayer.position / osd.activePlayer.length) * parent.width;
                                    }
                                    height: parent.height
                                    radius: 2
                                    color: "white"
                                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    function updatePosition(mouse) {
                                        if (osd.activePlayer && osd.activePlayer.lengthSupported) {
                                            osd.activePlayer.position = Math.max(0, Math.min(1.0, mouse.x / width)) * osd.activePlayer.length;
                                        }
                                    }
                                    onClicked: mouse => updatePosition(mouse)
                                    onPositionChanged: mouse => { if (pressed) updatePosition(mouse) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: osd.activePlayer && osd.activePlayer.positionSupported ? osd.formatTime(osd.activePlayer.position) : "0:00"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.pixelSize: 11
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: osd.activePlayer && osd.activePlayer.lengthSupported ? "-" + osd.formatTime(osd.activePlayer.length - osd.activePlayer.position) : "-0:00"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
