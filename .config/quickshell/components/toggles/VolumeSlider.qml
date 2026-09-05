import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Pipewire
import Quickshell.Io
import ".."

// VolumeSlider.qml — Pipewire audio volume slider.
// Context: shellRoot (icons), qs (audioNode), controlPanel (editMode)

Item {
    id: root
    property bool isControlWidget: true
    property string toggleName: "Volume"
    property var modelData: parent ? parent.modelData : ({})

    property var availableSizes: [
        { colSpan: 1, rowSpan: 2 },
        { colSpan: 2, rowSpan: 1 },
        { colSpan: 4, rowSpan: 1 }
    ]

    property bool isVertical: modelData && modelData.colSpan === 1 && modelData.rowSpan === 2

    property bool isPressed: isVertical ? vSlider.pressed : slider.pressed

    // Expanded view support
    property bool hasExpandedView: true
    property int expandedHeight: 520
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot
            implicitHeight: expandedContent.implicitHeight

            // Track all device nodes so their volume/mute properties bind
            PwObjectTracker {
                id: deviceTracker
                objects: {
                    let result = [];
                    if (Pipewire.defaultAudioSink) result.push(Pipewire.defaultAudioSink);
                    if (Pipewire.defaultAudioSource) result.push(Pipewire.defaultAudioSource);
                    let allNodes = Pipewire.nodes ? Pipewire.nodes.values : [];
                    for (let i = 0; i < allNodes.length; i++) {
                        let n = allNodes[i];
                        if (n && (n.isSink || n.isStream)) {
                            result.push(n);
                        }
                    }
                    return result;
                }
            }

            // Track streams connected to the default sink
            PwNodeLinkTracker {
                id: sinkLinkTracker
                node: Pipewire.defaultAudioSink
            }

            property int currentTab: 0 // 0: Devices, 1: Applications

            ColumnLayout {
                id: expandedContent
                anchors.fill: parent
                spacing: 16

                // ── Master Volume Slider (4x1 style) ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    Slider {
                        id: masterSlider
                        anchors.fill: parent
                        from: 0; to: 100
                        value: qs.audioNode ? qs.audioNode.volume * 100 : 50
                        onMoved: {
                            if (qs.audioNode) qs.audioNode.volume = value / 100.0
                        }
                        padding: 0

                        background: Item {
                            id: masterBgTrack
                            anchors.fill: parent

                            // Content layer (clipped to pill shape via OpacityMask)
                            Item {
                                id: masterTrackContent
                                anchors.fill: parent
                                visible: false

                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.rgba(1, 1, 1, 0.15)
                                }

                                Item {
                                    width: masterBgTrack.height; height: masterBgTrack.height
                                    Image {
                                        id: masterBgIcon
                                        anchors.centerIn: parent
                                        sourceSize: Qt.size(28, 28)
                                        source: shellRoot.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                                        visible: false
                                    }
                                    ColorOverlay {
                                        anchors.fill: masterBgIcon
                                        source: masterBgIcon
                                        color: "white"
                                        opacity: 0.5
                                    }
                                }

                                Rectangle {
                                    width: masterSlider.visualPosition * masterBgTrack.width
                                    height: masterBgTrack.height
                                    color: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)

                                    Item {
                                        x: 0
                                        width: masterBgTrack.height; height: masterBgTrack.height
                                        Image {
                                            id: masterFgIcon
                                            anchors.centerIn: parent
                                            sourceSize: Qt.size(28, 28)
                                            source: shellRoot.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                                            visible: false
                                        }
                                        ColorOverlay {
                                            anchors.fill: masterFgIcon
                                            source: masterFgIcon
                                            color: "white"
                                        }
                                    }
                                }

                                // Volume percentage label
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Math.round(masterSlider.value) + "%"
                                    color: Qt.rgba(1, 1, 1, 0.8)
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            // Pill-shaped mask
                            Rectangle {
                                id: masterMask
                                anchors.fill: parent
                                radius: height / 2
                                visible: false
                            }

                            OpacityMask {
                                anchors.fill: parent
                                source: masterTrackContent
                                maskSource: masterMask
                            }
                        }

                        handle: Item {}
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.1)
                }

                // ── Pill-style Tab Bar ──
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 20
                    color: Qt.rgba(1, 1, 1, 0.06)

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3

                        Repeater {
                            model: ["Devices", "Applications"]
                            delegate: Item {
                                width: parent.width / 2
                                height: parent.height

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 17
                                    color: expandedRoot.currentTab === index ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: expandedRoot.currentTab === index ? "white" : Qt.rgba(1, 1, 1, 0.5)
                                        font.pixelSize: 13
                                        font.bold: expandedRoot.currentTab === index
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: expandedRoot.currentTab = index
                                }
                            }
                        }
                    }
                }

                // ── Tab Content ──
                Flickable {
                    id: tabFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: tabContent.implicitHeight
                    contentHeight: tabContent.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar { }

                    ColumnLayout {
                        id: tabContent
                        width: tabFlickable.width
                        spacing: 8

                        // ════════════════════════════
                        // TAB 0: DEVICES
                        // ════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: expandedRoot.currentTab === 0

                            // --- Output Devices ---
                            Text {
                                text: "Output"
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 12
                                font.bold: true
                                Layout.leftMargin: 4
                                Layout.topMargin: 4
                            }

                            Repeater {
                                id: outputRepeater
                                model: {
                                    let nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
                                    let filtered = nodes.filter(function(n) {
                                        return n && n.isSink && !n.isStream && n.audio;
                                    });
                                    // Sort: default device first
                                    let defSink = Pipewire.defaultAudioSink;
                                    filtered.sort(function(a, b) {
                                        if (a === defSink) return -1;
                                        if (b === defSink) return 1;
                                        return 0;
                                    });
                                    return filtered;
                                }
                                delegate: deviceDelegate
                            }

                            Text {
                                visible: outputRepeater.count === 0
                                text: "No output devices found"
                                color: Qt.rgba(1, 1, 1, 0.3)
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 12
                            }

                            // --- Input Devices ---
                            Text {
                                text: "Input"
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 12
                                font.bold: true
                                Layout.leftMargin: 4
                                Layout.topMargin: 16
                            }

                            Repeater {
                                id: inputRepeater
                                model: {
                                    let nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
                                    return nodes.filter(function(n) {
                                        return n && !n.isSink && !n.isStream && n.audio;
                                    });
                                }
                                delegate: deviceDelegate
                            }

                            // Fallback: if the above filter produces nothing, try without audio check
                            Repeater {
                                id: inputRepeaterAlt
                                visible: inputRepeater.count === 0
                                model: {
                                    if (inputRepeater.count > 0) return [];
                                    let nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
                                    return nodes.filter(function(n) {
                                        return n && !n.isSink && !n.isStream;
                                    });
                                }
                                delegate: deviceDelegate
                            }

                            Text {
                                visible: inputRepeater.count === 0 && inputRepeaterAlt.count === 0
                                text: "No input devices found"
                                color: Qt.rgba(1, 1, 1, 0.3)
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 12
                            }
                        }

                        // ════════════════════════════
                        // TAB 1: APPLICATIONS
                        // ════════════════════════════
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: expandedRoot.currentTab === 1

                            Text {
                                text: "Playing"
                                color: Qt.rgba(1, 1, 1, 0.4)
                                font.pixelSize: 12
                                font.bold: true
                                Layout.leftMargin: 4
                                Layout.topMargin: 4
                            }

                            Repeater {
                                id: streamRepeater
                                model: {
                                    let nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
                                    return nodes.filter(function(n) {
                                        return n && n.isStream && n.audio;
                                    });
                                }
                                delegate: streamDelegate
                            }

                            Text {
                                visible: streamRepeater.count === 0
                                text: "No applications playing audio"
                                color: Qt.rgba(1, 1, 1, 0.3)
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 40
                            }
                        }
                    }
                }
            }

            // ── Device Delegate ──
            Component {
                id: deviceDelegate
                Rectangle {
                    Layout.fillWidth: true
                    height: 64
                    radius: 14
                    color: deviceMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    property bool isDefaultSink: Pipewire.defaultAudioSink && modelData && Pipewire.defaultAudioSink === modelData
                    property bool isDefaultSource: Pipewire.defaultAudioSource && modelData && Pipewire.defaultAudioSource === modelData
                    property bool isDefault: isDefaultSink || isDefaultSource

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Mute button
                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: (modelData && modelData.audio && modelData.audio.muted) ? Qt.rgba(1, 0.3, 0.3, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Image {
                                anchors.centerIn: parent
                                sourceSize: Qt.size(18, 18)
                                source: shellRoot.icon((modelData && modelData.audio && modelData.audio.muted) ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (modelData && modelData.audio) modelData.audio.muted = !modelData.audio.muted
                                }
                            }
                        }

                        // Name + slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: {
                                        if (!modelData) return "Unknown";
                                        return modelData.description || modelData.name || "Audio Device";
                                    }
                                    color: "white"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Default indicator
                                Rectangle {
                                    visible: isDefault
                                    width: defaultLabel.implicitWidth + 16
                                    height: 20
                                    radius: 10
                                    color: Qt.rgba(0.2, 0.5, 1.0, 0.3)

                                    Text {
                                        id: defaultLabel
                                        anchors.centerIn: parent
                                        text: "Default"
                                        color: Qt.rgba(0.4, 0.7, 1.0, 1.0)
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }
                            }

                            // Volume slider
                            Slider {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                from: 0; to: 100
                                value: (modelData && modelData.audio) ? modelData.audio.volume * 100 : 0
                                onMoved: {
                                    if (modelData && modelData.audio) modelData.audio.volume = value / 100.0
                                }

                                background: Rectangle {
                                    x: parent.leftPadding
                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: parent.availableWidth
                                    height: 8
                                    radius: 4
                                    color: Qt.rgba(1, 1, 1, 0.1)

                                    Rectangle {
                                        width: parent.parent.visualPosition * parent.width
                                        height: parent.height
                                        radius: 4
                                        color: isDefault ? shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0) : Qt.rgba(1, 1, 1, 0.4)
                                    }
                                }

                                handle: Rectangle {
                                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: 18; height: 18; radius: 9
                                    color: "white"
                                    scale: parent.pressed ? 1.2 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: deviceMouse
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        onClicked: {
                            // Set as default device
                            if (modelData && modelData.id !== undefined) {
                                setDefaultProc.command = ["wpctl", "set-default", String(modelData.id)]
                                setDefaultProc.running = true
                            }
                        }
                    }

                    Process {
                        id: setDefaultProc
                        running: false
                    }
                }
            }

            // ── Stream (Application) Delegate ──
            Component {
                id: streamDelegate
                Rectangle {
                    Layout.fillWidth: true
                    height: 64
                    radius: 14
                    color: streamMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        // Mute button
                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: (modelData && modelData.audio && modelData.audio.muted) ? Qt.rgba(1, 0.3, 0.3, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                            Behavior on color { ColorAnimation { duration: 200 } }

                            Image {
                                anchors.centerIn: parent
                                sourceSize: Qt.size(18, 18)
                                source: shellRoot.icon((modelData && modelData.audio && modelData.audio.muted) ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (modelData && modelData.audio) modelData.audio.muted = !modelData.audio.muted
                                }
                            }
                        }

                        // Name + slider
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: {
                                    if (!modelData) return "Unknown";
                                    return modelData.description || modelData.name || "Application";
                                }
                                color: "white"
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Slider {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 20
                                from: 0; to: 100
                                value: (modelData && modelData.audio) ? modelData.audio.volume * 100 : 0
                                onMoved: {
                                    if (modelData && modelData.audio) modelData.audio.volume = value / 100.0
                                }

                                background: Rectangle {
                                    x: parent.leftPadding
                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: parent.availableWidth
                                    height: 8
                                    radius: 4
                                    color: Qt.rgba(1, 1, 1, 0.1)

                                    Rectangle {
                                        width: parent.parent.visualPosition * parent.width
                                        height: parent.height
                                        radius: 4
                                        color: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    }
                                }

                                handle: Rectangle {
                                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: 18; height: 18; radius: 9
                                    color: "white"
                                    scale: parent.pressed ? 1.2 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: streamMouse
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                    }
                }
            }
        }
    }
    signal expandRequested()

    // ── Horizontal slider (2x1, 4x1) ──
    Slider {
        id: slider
        anchors.fill: parent
        visible: !root.isVertical
        from: 0; to: 100
        value: qs.audioNode ? qs.audioNode.volume * 100 : 50
        onMoved: {
            if (root.holdTriggered) return;
            if (qs.audioNode) qs.audioNode.volume = value / 100.0
            holdTimer.stop()
        }
        padding: 0

        background: Rectangle {
            id: bgTrack
            anchors.fill: parent
            radius: 0
            color: "transparent"
            clip: true

            Item {
                width: bgTrack.height; height: bgTrack.height
                Image {
                    id: bgIcon
                    anchors.centerIn: parent
                    sourceSize: Qt.size(28, 28)
                    source: shellRoot.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: bgIcon
                    source: bgIcon
                    color: "white"
                    opacity: 0.5
                }
            }

            MaterialSurface {
                id: hSliderSurface
                width: slider.visualPosition * bgTrack.width
                height: bgTrack.height
                radius: 0
                isActive: true
                clip: true
                
                Item {
                    x: 0
                    width: bgTrack.height; height: bgTrack.height
                    Image {
                        id: fgIcon
                        anchors.centerIn: parent
                        sourceSize: Qt.size(28, 28)
                        source: shellRoot.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: fgIcon
                        source: fgIcon
                        color: hSliderSurface.iconColor
                    }
                }
            }
        }
        
        handle: Item {}

        onPressedChanged: {
            if (pressed) {
                root.holdTriggered = false
                holdTimer.restart()
            } else {
                holdTimer.stop()
                if (!root.holdTriggered) {
                    // Apply volume on short tap or release
                    if (qs.audioNode) qs.audioNode.volume = value / 100.0
                }
                // Restore binding so the slider tracks external volume changes again
                slider.value = Qt.binding(function() { return qs.audioNode ? qs.audioNode.volume * 100 : 50 })
            }
        }
    }

    // ── Vertical slider (1x2) ──
    Slider {
        id: vSlider
        anchors.fill: parent
        visible: root.isVertical
        orientation: Qt.Vertical
        from: 0; to: 100
        value: qs.audioNode ? qs.audioNode.volume * 100 : 50
        onMoved: {
            if (root.holdTriggered) return;
            if (qs.audioNode) qs.audioNode.volume = value / 100.0
            holdTimer.stop()
        }
        padding: 0

        background: Rectangle {
            id: vBgTrack
            anchors.fill: parent
            radius: 0
            color: "transparent"
            clip: true

            // Icon at the bottom of the track
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                width: vBgTrack.width; height: vBgTrack.width
                Image {
                    id: vBgIcon
                    anchors.centerIn: parent
                    sourceSize: Qt.size(24, 24)
                    source: shellRoot.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: vBgIcon
                    source: vBgIcon
                    color: "white"
                    opacity: 0.5
                }
            }

            // Filled portion (grows upward from bottom)
            MaterialSurface {
                id: vSliderSurface
                width: vBgTrack.width
                height: (1.0 - vSlider.visualPosition) * vBgTrack.height
                anchors.bottom: parent.bottom
                radius: 0
                isActive: true
                clip: true

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    width: vBgTrack.width; height: vBgTrack.width
                    Image {
                        id: vFgIcon
                        anchors.centerIn: parent
                        sourceSize: Qt.size(24, 24)
                        source: shellRoot.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: vFgIcon
                        source: vFgIcon
                        color: vSliderSurface.iconColor
                    }
                }
            }
        }

        handle: Item {}

        onPressedChanged: {
            if (pressed) {
                root.holdTriggered = false
                holdTimer.restart()
            } else {
                holdTimer.stop()
                if (!root.holdTriggered) {
                    if (qs.audioNode) qs.audioNode.volume = value / 100.0
                }
                vSlider.value = Qt.binding(function() { return qs.audioNode ? qs.audioNode.volume * 100 : 50 })
            }
        }
    }

    property bool holdTriggered: false
    Timer {
        id: holdTimer
        interval: 300
        onTriggered: {
            root.holdTriggered = true
            root.expandRequested()
            // Restore visual value so the slider snaps back if the user lifts their finger
            if (qs.audioNode) {
                slider.value = qs.audioNode.volume * 100
                vSlider.value = qs.audioNode.volume * 100
            }
        }
    }

    // Block slider interaction during edit mode
    MouseArea {
        anchors.fill: parent
        enabled: controlPanel.editMode
    }
}
