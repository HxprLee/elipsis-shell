import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Pipewire
import Quickshell.Io
import ".."
import "../../services"

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
            // Static height: matches BluetoothToggle. Card uses expandedHeight
            // (above) as its morph target; no dynamic resize. Tab content
            // scrolls inside the card via Flickable.

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

                // ── Master Volume Slider block ──
                // Header row above the pill: device title (left) + "Active" badge (right)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20

                    Text {
                        id: masterDeviceTitle
                        anchors.left: parent.left
                        anchors.right: activeBadge.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: Pipewire.defaultAudioSink ? (Pipewire.defaultAudioSink.nickname || Pipewire.defaultAudioSink.description || Pipewire.defaultAudioSink.name) : "Output"
                        color: Qt.rgba(1, 1, 1, 0.9)
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Rectangle {
                        id: activeBadge
                        visible: qs.audioNode !== undefined
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18
                        implicitWidth: activeBadgeText.implicitWidth + 12
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.1)
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1

                        Text {
                            id: activeBadgeText
                            anchors.centerIn: parent
                            text: "Active"
                            color: Qt.rgba(1, 1, 1, 0.9)
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // Pill slider
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    Slider {
                        id: masterSlider
                        anchors.fill: parent
                        from: 0; to: 100
                        value: qs.audioNode ? qs.audioNode.volume * 100 : 50
                        property bool didDrag: false
                        onMoved: {
                            if (qs.audioNode) qs.audioNode.volume = value / 100.0
                            didDrag = true
                        }
                        onPressedChanged: {
                            if (pressed) {
                                didDrag = false
                            } else {
                                if (!didDrag && qs.audioNode) masterSlider.value = qs.audioNode.volume * 100
                                masterSlider.value = Qt.binding(function() { return qs.audioNode ? qs.audioNode.volume * 100 : 50 })
                            }
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
                                        source: Icons.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                                        visible: false
                                    }
                                    ColorOverlay {
                                        anchors.fill: masterBgIcon
                                        source: masterBgIcon
                                        color: "white"
                                        opacity: 0.5
                                    }
                                }

                                MaterialSurface {
                                    id: masterFillSurface
                                    width: masterSlider.visualPosition * masterBgTrack.width
                                    height: masterBgTrack.height
                                    radius: 0
                                    isActive: true
                                    clip: true

                                    Item {
                                        x: 0
                                        width: masterBgTrack.height; height: masterBgTrack.height
                                        Image {
                                            id: masterFgIcon
                                            anchors.centerIn: parent
                                            sourceSize: Qt.size(28, 28)
                                            source: Icons.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
                                            visible: false
                                        }
                                        ColorOverlay {
                                            anchors.fill: masterFgIcon
                                            source: masterFgIcon
                                            color: masterFillSurface.iconColor
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

                // ── Pill-style Tab Bar (inverted selected pill, 40px) ──
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 20
                    color: Qt.rgba(1, 1, 1, 0.2)

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
                                    color: expandedRoot.currentTab === index ? Qt.rgba(1, 1, 1, 0.8) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: expandedRoot.currentTab === index ? Qt.rgba(0.117, 0.117, 0.117, 0.8) : Qt.rgba(1, 1, 1, 0.8)
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
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
                                    // Hide unplugged ports (pavucontrol behavior). Always keep the default.
                                    if (PipewireAvailability.ready) {
                                        let defSink = Pipewire.defaultAudioSink;
                                        filtered = filtered.filter(function(n) {
                                            return n === defSink || !PipewireAvailability.isUnplugged(n.id);
                                        });
                                    }
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
                                    let filtered = nodes.filter(function(n) {
                                        return n && !n.isSink && !n.isStream && n.audio;
                                    });
                                    // Hide unplugged ports. Always keep the default source.
                                    if (PipewireAvailability.ready) {
                                        let defSrc = Pipewire.defaultAudioSource;
                                        filtered = filtered.filter(function(n) {
                                            return n === defSrc || !PipewireAvailability.isUnplugged(n.id);
                                        });
                                    }
                                    return filtered;
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
                                    let filtered = nodes.filter(function(n) {
                                        return n && !n.isSink && !n.isStream;
                                    });
                                    if (PipewireAvailability.ready) {
                                        let defSrc = Pipewire.defaultAudioSource;
                                        filtered = filtered.filter(function(n) {
                                            return n === defSrc || !PipewireAvailability.isUnplugged(n.id);
                                        });
                                    }
                                    return filtered;
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
                Item {
                    id: rowRoot
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    readonly property bool isDefault:
                        (modelData && Pipewire.defaultAudioSink && Pipewire.defaultAudioSink === modelData)
                        || (modelData && Pipewire.defaultAudioSource && Pipewire.defaultAudioSource === modelData)

                    // Live volume (0-100) — updated by the slider MouseArea during drag
                    // and read by the fill rectangle. Binds to the actual volume when
                    // the user isn't interacting.
                    property real deviceVolumePercent:
                        (modelData && modelData.audio) ? modelData.audio.volume * 100 : 0

                    // Pill-shaped slider: track + fill wrapped in an OpacityMask
                    // so the inner fill is a sharp rectangle clipped to the pill.
                    Item {
                        id: deviceTrack
                        anchors.fill: parent

                        // Content layer (clipped to pill shape via OpacityMask)
                        Item {
                            id: deviceTrackContent
                            anchors.fill: parent
                            visible: false

                            // Track background
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(1, 1, 1, 0.15)
                            }

                            // Filled portion. Active (accent) when not muted, dim/transparent
                            // when muted. "Default device" no longer affects the fill color —
                            // every non-muted device row uses the accent.
                            MaterialSurface {
                                id: deviceFillSurface
                                width: (deviceVolumePercent / 100) * deviceTrack.width
                                height: deviceTrack.height
                                radius: 0
                                isActive: !(modelData && modelData.audio && modelData.audio.muted)
                                opacity: deviceVolumePercent > 0 ? 1.0 : 0.0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        // Pill mask
                        Rectangle {
                            id: deviceMask
                            anchors.fill: parent
                            radius: height / 2
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: deviceTrackContent
                            maskSource: deviceMask
                        }
                    }

                    // Single MouseArea handles all touch interaction:
                    //   - clean tap (no drag) → set as default device
                    //   - horizontal drag     → adjust volume
                    //   - vertical drag       → ignored (Flickable scrolls the list)
                    // The visual fill mirrors `rowRoot.deviceVolumePercent`, which
                    // re-evaluates as `modelData.audio.volume` changes during drag.
                    // preventStealing + asymmetric deadzone: 8 px to commit to either
                    // axis, but once a horizontal drag is committed, allow up to 24 px
                    // of vertical drift before surrendering to the Flickable.
                    MouseArea {
                        id: deviceSliderArea
                        anchors.fill: parent
                        preventStealing: true
                        readonly property int hDeadzone: 8
                        readonly property int vDeadzone: 24
                        property real startX: 0
                        property real startY: 0
                        property bool horizontalDrag: false
                        property bool verticalDrag: false
                        onPressed: (mouse) => {
                            startX = mouse.x
                            startY = mouse.y
                            horizontalDrag = false
                            verticalDrag = false
                            mouse.accepted = true
                        }
                        onPositionChanged: (mouse) => {
                            if (!horizontalDrag && Math.abs(mouse.x - startX) > hDeadzone)
                                horizontalDrag = true
                            if (!verticalDrag && Math.abs(mouse.y - startY) > vDeadzone)
                                verticalDrag = true
                            if (horizontalDrag && !verticalDrag && modelData && modelData.audio) {
                                let pct = Math.max(0, Math.min(100, (mouse.x / width) * 100))
                                modelData.audio.volume = pct / 100
                            }
                            mouse.accepted = horizontalDrag || !verticalDrag
                        }
                        onReleased: {
                            if (!horizontalDrag && !verticalDrag) {
                                SystemActions.setDefaultAudio(modelData ? modelData.id : undefined)
                            }
                        }
                    }

                    // Icon (left) — click to mute, decorative otherwise
                    Item {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28
                        z: 2

                        Image {
                            anchors.fill: parent
                            sourceSize: Qt.size(28, 28)
                            source: Icons.icon((modelData && modelData.audio && modelData.audio.muted)
                                ? "audio-volume-muted-symbolic"
                                : "audio-volume-high-symbolic")
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: parent
                            source: parent.children[0]
                            color: deviceFillSurface.iconColor
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData && modelData.audio) modelData.audio.muted = !modelData.audio.muted
                            }
                        }
                    }

                    // Name + "Active" subtitle
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 52
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 1
                        z: 1

                        Text {
                            text: modelData ? (modelData.nickname || modelData.description || modelData.name || "Audio Device") : ""
                            color: deviceFillSurface.fgColor
                            opacity: 0.7
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: rowRoot.isDefault
                            text: "Active"
                            color: deviceFillSurface.fgColor
                            opacity: 0.7
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            // ── Stream (Application) Delegate ──
            Component {
                id: streamDelegate
                Item {
                    id: streamRoot
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    // Live volume (0-100). Read by the fill rectangle; updates
                    // when the user drags the slider or when the stream volume
                    // changes externally (e.g. app-side).
                    property real streamVolumePercent:
                        (modelData && modelData.audio) ? modelData.audio.volume * 100 : 0

                    // Pill-shaped slider: track + fill wrapped in an OpacityMask
                    // so the inner fill is a sharp rectangle clipped to the pill.
                    Item {
                        id: streamTrack
                        anchors.fill: parent

                        // Content layer (clipped to pill shape via OpacityMask)
                        Item {
                            id: streamTrackContent
                            anchors.fill: parent
                            visible: false

                            // Track background
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(1, 1, 1, 0.15)
                            }

                            // Filled portion. Active (accent) when not muted, dim/transparent
                            // when muted.
                            MaterialSurface {
                                id: streamFillSurface
                                width: (streamVolumePercent / 100) * streamTrack.width
                                height: streamTrack.height
                                radius: 0
                                isActive: !(modelData && modelData.audio && modelData.audio.muted)
                                opacity: streamVolumePercent > 0 ? 1.0 : 0.0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        // Pill mask
                        Rectangle {
                            id: streamMask
                            anchors.fill: parent
                            radius: height / 2
                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent
                            source: streamTrackContent
                            maskSource: streamMask
                        }
                    }

                    // Slider underlay for drag-to-set
                    Slider {
                        id: streamSlider
                        anchors.fill: parent
                        from: 0; to: 100
                        value: (modelData && modelData.audio) ? modelData.audio.volume * 100 : 0
                        property bool didDrag: false
                        onMoved: {
                            if (modelData && modelData.audio) modelData.audio.volume = value / 100.0
                            didDrag = true
                        }
                        onPressedChanged: {
                            if (pressed) {
                                didDrag = false
                            } else {
                                if (!didDrag && modelData && modelData.audio) streamSlider.value = modelData.audio.volume * 100
                                streamSlider.value = Qt.binding(function() { return (modelData && modelData.audio) ? modelData.audio.volume * 100 : 0 })
                            }
                        }
                        padding: 0
                        handle: Item {}
                        background: Item {}
                    }

                    // Icon (left) — click to mute
                    Item {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28
                        z: 2

                        Image {
                            anchors.fill: parent
                            sourceSize: Qt.size(28, 28)
                            source: Icons.icon((modelData && modelData.audio && modelData.audio.muted)
                                ? "audio-volume-muted-symbolic"
                                : "audio-volume-high-symbolic")
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: parent
                            source: parent.children[0]
                            color: streamFillSurface.iconColor
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData && modelData.audio) modelData.audio.muted = !modelData.audio.muted
                            }
                        }
                    }

                    // Name only (no subtitle for streams)
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 52
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        verticalAlignment: Text.AlignVCenter
                        text: modelData ? (modelData.description || modelData.name || "Application") : ""
                        color: streamFillSurface.fgColor
                        opacity: 0.7
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        z: 1
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
        property bool didDrag: false
        onMoved: {
            if (root.holdTriggered) return;
            // Cancel hold-to-expand on first movement so swipes don't open expandedUI.
            holdTimer.stop();
            if (qs.audioNode) qs.audioNode.volume = value / 100.0
            didDrag = true
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
                    source: Icons.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
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
                        source: Icons.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
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
                if (expandedOverlay.isExpanded) return;
                root.holdTriggered = false
                holdTimer.restart()
                didDrag = false
            } else {
                holdTimer.stop()
                if (expandedOverlay.isExpanded) {
                    slider.value = Qt.binding(function() { return qs.audioNode ? qs.audioNode.volume * 100 : 50 })
                    return
                }
                if (!root.holdTriggered) {
                    if (didDrag) {
                        if (qs.audioNode) qs.audioNode.volume = value / 100.0
                    } else if (qs.audioNode) {
                        // Tap: snap value back to current volume
                        slider.value = qs.audioNode.volume * 100
                    }
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
        property bool didDrag: false
        onMoved: {
            if (root.holdTriggered) return;
            // Cancel hold-to-expand on first movement so swipes don't open expandedUI.
            holdTimer.stop();
            if (qs.audioNode) qs.audioNode.volume = value / 100.0
            didDrag = true
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
                    source: Icons.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
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
                        source: Icons.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
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
                if (expandedOverlay.isExpanded) return;
                root.holdTriggered = false
                holdTimer.restart()
                didDrag = false
            } else {
                holdTimer.stop()
                if (expandedOverlay.isExpanded) {
                    vSlider.value = Qt.binding(function() { return qs.audioNode ? qs.audioNode.volume * 100 : 50 })
                    return
                }
                if (!root.holdTriggered) {
                    if (didDrag) {
                        if (qs.audioNode) qs.audioNode.volume = value / 100.0
                    } else if (qs.audioNode) {
                        vSlider.value = qs.audioNode.volume * 100
                    }
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
            if (expandedOverlay.isExpanded) return;
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
