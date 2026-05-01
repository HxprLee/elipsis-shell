import Quickshell
import Quickshell.Services.Pipewire
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
    }

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrLayershell.None

    implicitHeight: 120
    margins.top: 50

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    property var audioNode: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    property real volume: audioNode ? audioNode.volume : 0
    property bool muted: audioNode ? audioNode.muted : false
    property bool isSlim: false
    property bool isInteracting: false
    property bool isInitialized: false

    onVolumeChanged: {
        if (!isInitialized || shellRoot.panelOpen) return;
        showOSD()
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
        interval: 1000 // Ignore volume changes during the first second
        onTriggered: osd.isInitialized = true
    }

    function showOSD() {
        if (!osd.visible || hideAnim.running) {
            osd.visible = true
            isSlim = false
            hideAnim.stop()
            showAnim.restart()
        } else if (!isInteracting) {
            isSlim = true
        }
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: hideAnim.start()
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "scale"; from: 0.8; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        NumberAnimation { target: content; property: "y"; from: -20; to: 0; duration: 400; easing.type: Easing.OutBack }
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InCubic }
        NumberAnimation { target: content; property: "scale"; to: 0.9; duration: 300; easing.type: Easing.InCubic }
        onFinished: {
            osd.visible = false
            osd.isSlim = false
            osd.isInteracting = false
        }
    }

    // --- The iOS Style Pill ---
    Rectangle {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        width: 220
        height: isSlim ? 8 : 48
        radius: height / 2
        color: Qt.rgba(0.1, 0.1, 0.15, 0.6) // Glass background
        
        opacity: 0
        scale: 0.8

        Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: content.width
                height: content.height
                radius: content.radius
            }
        }

        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        // The "Slider" Progress Fill (Reversed: anchors to right)
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

        // Interactive Slider Area
        MouseArea {
            anchors.fill: parent
            enabled: osd.visible
            
            function handleVolume(mouse) {
                if (osd.audioNode) {
                    osd.isInteracting = true
                    // Reversed logic: width starts from right
                    let ratio = (parent.width - mouse.x) / parent.width
                    osd.audioNode.volume = Math.max(0, Math.min(1, ratio))
                    hideTimer.restart()
                }
            }

            onPressed: (mouse) => handleVolume(mouse)
            onPositionChanged: (mouse) => handleVolume(mouse)
            onReleased: {
                osd.isInteracting = false
                hideTimer.restart()
            }
        }

        // Icon and Text Row
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
                // Left side: inverts when bar reaches all the way across
                color: (progressFill.width > 185) ? "#111" : "white"
                font.pixelSize: 14
                font.weight: Font.Bold
                Behavior on color { ColorAnimation { duration: 200 } }
            }

            Item { Layout.fillWidth: true } // Spacer

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
                    // Right side: inverts early as bar grows from the right
                    color: (progressFill.width > 30) ? "#111" : "white" 
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
    }
}
