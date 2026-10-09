import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import ".."
import "../reusables"
import "../../services"
// BrightnessSlider.qml — Backlight brightness slider using logind/sysfs.
// Context: shellRoot (icons), qs (brightnessValue, setBrightness), controlPanel (editMode)

Item {
    id: root
    property bool isControlWidget: true
    property string toggleName: "Brightness"
    property var modelData: parent ? parent.modelData : ({})

    property var availableSizes: [
        { colSpan: 1, rowSpan: 2 },
        { colSpan: 2, rowSpan: 1 },
        { colSpan: 4, rowSpan: 1 }
    ]

    property bool isVertical: modelData && modelData.colSpan === 1 && modelData.rowSpan === 2

    property bool isPressed: isVertical ? vSlider.pressed : slider.pressed

    // ── Horizontal slider (2x1, 4x1) ──
    Slider {
        id: slider
        anchors.fill: parent
        visible: !root.isVertical
        from: 1; to: 100
        value: Brightness.brightnessValue
        onMoved: {
            if (root.holdTriggered) return;
            Brightness.setBrightness(value);
            holdTimer.stop();
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
                    source: Icons.icon("display-brightness-symbolic")
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
                        source: Icons.icon("display-brightness-symbolic")
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
                root.holdTriggered = false;
                holdTimer.restart();
            } else {
                holdTimer.stop();
                if (expandedOverlay.isExpanded) return;
                if (!root.holdTriggered) {
                    Brightness.setBrightness(value);
                }
                // Restore binding so the slider tracks external brightness changes again
                slider.value = Qt.binding(function() { return Brightness.brightnessValue });
            }
        }
    }

    // ── Vertical slider (1x2) ──
    Slider {
        id: vSlider
        anchors.fill: parent
        visible: root.isVertical
        orientation: Qt.Vertical
        from: 1; to: 100
        value: Brightness.brightnessValue
        onMoved: {
            if (root.holdTriggered) return;
            Brightness.setBrightness(value);
            holdTimer.stop();
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
                    source: Icons.icon("display-brightness-symbolic")
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
                        source: Icons.icon("display-brightness-symbolic")
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
                root.holdTriggered = false;
                holdTimer.restart();
            } else {
                holdTimer.stop();
                if (expandedOverlay.isExpanded) return;
                if (!root.holdTriggered) {
                    Brightness.setBrightness(value);
                }
                vSlider.value = Qt.binding(function() { return Brightness.brightnessValue });
            }
        }
    }

    property bool holdTriggered: false
    Timer {
        id: holdTimer
        interval: 300
        onTriggered: {
            if (expandedOverlay.isExpanded) return;
            root.holdTriggered = true;
            root.expandRequested();
            if (slider.value !== Brightness.brightnessValue) slider.value = Brightness.brightnessValue;
            if (vSlider.value !== Brightness.brightnessValue) vSlider.value = Brightness.brightnessValue;
        }
    }
    signal expandRequested()

    // ── Expanded view (no header, single MaterialSurface card) ──
    property bool hasExpandedView: true
    property int expandedHeight: 400
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot
            implicitHeight: 400

            // Click-outside to close (z: -1 so it doesn't block inner interactions)
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: controlPanel.closeExpandedView()
            }

            // Direct content — the outer widgetBg cell already provides
            // the rounded card chrome (its MaterialSurface is the morph target).
            ColumnLayout {
                anchors.fill: parent

                // ── Display slider ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Display"
                        color: "white"
                        font.pixelSize: 14
                        font.bold: true
                    }

                    // Pill slider — mirrors VolumeSlider's masterSlider structure
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 56

                        Slider {
                            id: brightnessSlider
                            anchors.fill: parent
                            from: 1; to: 100
                            value: Brightness.brightnessValue
                            padding: 0
                            onMoved: Brightness.setBrightness(value)

                            background: Item {
                                id: brightnessBgTrack
                                anchors.fill: parent

                                // Content layer (clipped to pill shape via OpacityMask)
                                Item {
                                    id: brightnessTrackContent
                                    anchors.fill: parent
                                    visible: false

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Qt.rgba(1, 1, 1, 0.15)
                                    }

                                    Item {
                                        width: brightnessBgTrack.height; height: brightnessBgTrack.height
                                        Image {
                                            id: brightnessBgIcon
                                            anchors.centerIn: parent
                                            sourceSize: Qt.size(28, 28)
                                            source: Icons.icon(Brightness.autoBrightnessActive
                                                ? "auto-brightness-symbolic"
                                                : "display-brightness-symbolic")
                                            visible: false
                                        }
                                        ColorOverlay {
                                            anchors.fill: brightnessBgIcon
                                            source: brightnessBgIcon
                                            color: "white"
                                            opacity: 0.5
                                        }
                                    }

                                    Rectangle {
                                        width: brightnessSlider.visualPosition * brightnessBgTrack.width
                                        height: brightnessBgTrack.height
                                        color: Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)

                                        Item {
                                            x: 0
                                            width: brightnessBgTrack.height; height: brightnessBgTrack.height
                                            Image {
                                                id: brightnessFgIcon
                                                anchors.centerIn: parent
                                                sourceSize: Qt.size(28, 28)
                                                source: Icons.icon(Brightness.autoBrightnessActive
                                                    ? "auto-brightness-symbolic"
                                                    : "display-brightness-symbolic")
                                                visible: false
                                            }
                                            ColorOverlay {
                                                anchors.fill: brightnessFgIcon
                                                source: brightnessFgIcon
                                                color: "white"
                                            }
                                        }
                                    }

                                    // Brightness percentage label
                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.round(Brightness.brightnessValue) + "%"
                                        color: Qt.rgba(1, 1, 1, 0.8)
                                        font.pixelSize: 14
                                        font.bold: true
                                    }

                                    // Click on the icon area toggles auto-brightness.
                                    // Mirrors the visual structure of VolumeSlider's master
                                    // slider; this MouseArea catches clicks before the
                                    // Slider sees them (z: 1, anchors.leftMargin scoped).
                                    MouseArea {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: brightnessBgTrack.height
                                        height: brightnessBgTrack.height
                                        z: 1
                                        onClicked: Brightness.setAutoBrightness(
                                            !Brightness.autoBrightnessActive)
                                    }
                                }

                                // Pill-shaped mask
                                Rectangle {
                                    id: brightnessMask
                                    anchors.fill: parent
                                    radius: height / 2
                                    visible: false
                                }

                                OpacityMask {
                                    anchors.fill: parent
                                    source: brightnessTrackContent
                                    maskSource: brightnessMask
                                }
                            }

                            handle: Item {}
                        }
                    }
                }

                    // ── Keyboard backlight slider ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: Brightness.kbdBacklightAvailable
                        spacing: 8

                        Text {
                            text: "Keyboard backlight"
                            color: "white"
                            font.pixelSize: 14
                            font.bold: true
                        }

                        // Segmented pill — discrete cells, kbdBacklightMax + 1 of them
                        Rectangle {
                            id: kbdPill
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            radius: 32
                            color: Qt.rgba(1, 1, 1, 0.15)
                            clip: true

                            Row {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Repeater {
                                    id: kbdSegments
                                    model: Math.max(1, Brightness.kbdBacklightMax + 1)
                                    delegate: Rectangle {
                                        width: (kbdPill.width - 8
                                            - 4 * (Brightness.kbdBacklightMax))
                                            / Math.max(1, Brightness.kbdBacklightMax + 1)
                                        height: kbdPill.height - 8
                                        radius: Math.min(width, height) / 2
                                        color: index <= Brightness.kbdBacklightValue
                                            ? (Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
                                            : Qt.rgba(1, 1, 1, 0.1)
                                        opacity: index <= Brightness.kbdBacklightValue ? 0.6 : 1.0
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }
                                }
                            }

                            // Keyboard icon (centered)
                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32; height: 32
                                z: 1
                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(24, 24)
                                    source: Icons.icon("input-keyboard-symbolic")
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: parent.children[0]
                                    source: parent.children[0]
                                    color: "white"
                                }
                            }

                            // Invisible slider for binding
                            Slider {
                                id: kbdSlider
                                anchors.fill: parent
                                from: 0; to: Math.max(1, Brightness.kbdBacklightMax)
                                value: Brightness.kbdBacklightValue
                                padding: 0
                                handle: Item {}
                                visible: false
                                onMoved: {
                                    let pct = Math.round((value / Math.max(1,
                                        Brightness.kbdBacklightMax)) * 100);
                                    Brightness.setKbdBacklight(pct);
                                }
                            }

                            // Click-to-set (snaps to nearest cell)
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    let cells = Brightness.kbdBacklightMax + 1;
                                    let cell = Math.round((mouseX / kbdPill.width) * cells);
                                    cell = Math.max(0, Math.min(Brightness.kbdBacklightMax, cell));
                                    let pct = Math.round((cell / Math.max(1,
                                        Brightness.kbdBacklightMax)) * 100);
                                    Brightness.setKbdBacklight(pct);
                                }
                                onPositionChanged: {
                                    if (pressed) {
                                        let cells = Brightness.kbdBacklightMax + 1;
                                        let cell = Math.round((mouseX / kbdPill.width) * cells);
                                        cell = Math.max(0, Math.min(Brightness.kbdBacklightMax, cell));
                                        let pct = Math.round((cell / Math.max(1,
                                            Brightness.kbdBacklightMax)) * 100);
                                        Brightness.setKbdBacklight(pct);
                                    }
                                }
                            }
                        }
                    }

                    // ── Toggle row (centered, two buttons) ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 40

                        // Night Light
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                Layout.alignment: Qt.AlignHCenter
                                radius: 28
                                color: Brightness.nightLightActive
                                    ? (Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
                                    : Qt.rgba(1, 1, 1, 0.15)
                                opacity: Brightness.nightLightActive ? 0.6 : 1.0
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(24, 24)
                                    source: Icons.icon("night-light-symbolic")
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: parent.children[0]
                                    source: parent.children[0]
                                    color: "white"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Brightness.setNightLight(
                                        !Brightness.nightLightActive)
                                }
                            }

                            Text {
                                text: "Night Light"
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }

                        // Dark Mode
                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 56
                                Layout.alignment: Qt.AlignHCenter
                                radius: 28
                                color: Brightness.darkModeActive
                                    ? (Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0))
                                    : Qt.rgba(1, 1, 1, 0.15)
                                opacity: Brightness.darkModeActive ? 0.6 : 1.0
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(24, 24)
                                    source: Icons.icon("dark-mode-symbolic")
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: parent.children[0]
                                    source: parent.children[0]
                                    color: "white"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: Brightness.setDarkMode(
                                        !Brightness.darkModeActive)
                                }
                            }

                            Text {
                                text: "Dark Mode"
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }

    // Block slider interaction during edit mode
    MouseArea {
        anchors.fill: parent
        enabled: controlPanel.editMode
    }
}
