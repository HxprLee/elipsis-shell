import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import ".."
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
        value: qs.brightnessValue
        onMoved: {
            if (root.holdTriggered) return;
            qs.setBrightness(value);
            holdTimer.restart();
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
                    source: shellRoot.icon("display-brightness-symbolic")
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
                        source: shellRoot.icon("display-brightness-symbolic")
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
                root.holdTriggered = false;
                holdTimer.restart();
            } else {
                holdTimer.stop();
                if (!root.holdTriggered) {
                    qs.setBrightness(value);
                }
                // Restore binding so the slider tracks external brightness changes again
                slider.value = Qt.binding(function() { return qs.brightnessValue });
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
        value: qs.brightnessValue
        onMoved: {
            if (root.holdTriggered) return;
            qs.setBrightness(value);
            holdTimer.restart();
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
                    source: shellRoot.icon("display-brightness-symbolic")
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
                        source: shellRoot.icon("display-brightness-symbolic")
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
                root.holdTriggered = false;
                holdTimer.restart();
            } else {
                holdTimer.stop();
                if (!root.holdTriggered) {
                    qs.setBrightness(value);
                }
                vSlider.value = Qt.binding(function() { return qs.brightnessValue });
            }
        }
    }

    property bool holdTriggered: false
    Timer {
        id: holdTimer
        interval: 300
        onTriggered: {
            root.holdTriggered = true;
            root.expandRequested();
            if (slider.value !== qs.brightnessValue) slider.value = qs.brightnessValue;
            if (vSlider.value !== qs.brightnessValue) vSlider.value = qs.brightnessValue;
        }
    }
    signal expandRequested()

    // ── Expanded view (no ExpandedHeader) ──
    property bool hasExpandedView: true
    property int expandedHeight: 480
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot
            implicitHeight: scrollView.implicitHeight

            // Click-outside to close (z: -1 so it doesn't block inner interactions)
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: controlPanel.closeExpandedView()
            }

            ScrollView {
                id: scrollView
                anchors.fill: parent
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: scrollView.availableWidth
                    spacing: 12

                    // ── Display Brightness ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Image {
                                sourceSize: Qt.size(16, 16)
                                source: shellRoot.icon("display-brightness-symbolic")
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                ColorOverlay {
                                    anchors.fill: parent
                                    source: parent
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                }
                            }
                            Text {
                                text: "Display Brightness"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: Math.round(qs.brightnessValue) + "%"
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.pixelSize: 13
                            }
                        }

                        MaterialSurface {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            isActive: true
                            clip: true
                            Slider {
                                id: expandedBrightnessSlider
                                anchors.fill: parent
                                anchors.margins: 8
                                from: 1; to: 100
                                value: qs.brightnessValue
                                padding: 0
                                handle: Item {}
                                background: Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: Qt.rgba(1, 1, 1, 0.1)
                                    Rectangle {
                                        width: parent.height
                                        height: parent.height
                                        radius: 4
                                        color: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                        Image {
                                            anchors.centerIn: parent
                                            sourceSize: Qt.size(16, 16)
                                            source: shellRoot.icon("display-brightness-symbolic")
                                            visible: false
                                        }
                                        ColorOverlay {
                                            anchors.fill: parent
                                            source: parent
                                            color: "white"
                                        }
                                    }
                                    Rectangle {
                                        x: parent.height
                                        width: expandedBrightnessSlider.visualPosition * (parent.width - parent.height)
                                        height: parent.height
                                        color: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    }
                                }
                                onMoved: qs.setBrightness(value)
                            }
                        }
                    }

                    // ── Keyboard Backlight ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Image {
                                sourceSize: Qt.size(16, 16)
                                source: shellRoot.icon("input-keyboard-symbolic")
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                ColorOverlay {
                                    anchors.fill: parent
                                    source: parent
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                }
                            }
                            Text {
                                text: "Keyboard Backlight"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: Math.round((qs.kbdBacklightValue / Math.max(1, qs.kbdBacklightMax)) * 100) + "%"
                                color: Qt.rgba(1, 1, 1, 0.5)
                                font.pixelSize: 13
                            }
                        }

                        MaterialSurface {
                            Layout.fillWidth: true
                            height: 40
                            radius: 8
                            isActive: true
                            clip: true
                            Slider {
                                id: vSliderKbd
                                anchors.fill: parent
                                anchors.margins: 8
                                from: 0; to: Math.max(1, qs.kbdBacklightMax)
                                value: qs.kbdBacklightValue
                                padding: 0
                                handle: Item {}
                                background: Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: Qt.rgba(1, 1, 1, 0.1)
                                    Rectangle {
                                        width: parent.height
                                        height: parent.height
                                        radius: 4
                                        color: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    }
                                    Rectangle {
                                        x: parent.height
                                        width: {
                                            let range = Math.max(1, qs.kbdBacklightMax);
                                            ((vSliderKbd.value - 0) / range) * (parent.width - parent.height);
                                        }
                                        height: parent.height
                                        color: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    }
                                }
                                onMoved: {
                                    let pct = Math.round((value / Math.max(1, qs.kbdBacklightMax)) * 100);
                                    qs.setKbdBacklight(pct);
                                }
                            }
                        }
                    }

                    // ── Divider ──
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // ── Dark Mode ──
                    ToggleListItem {
                        Layout.fillWidth: true
                        label: "Dark Mode"
                        iconSource: shellRoot.icon("dark-mode-symbolic")
                        isActive: qs.darkModeActive
                        activeColor: shellRoot.accentColor
                        onToggle: qs.setDarkMode(!qs.darkModeActive)
                    }

                    // ── Night Light (placeholder) ──
                    ToggleListItem {
                        Layout.fillWidth: true
                        label: "Night Light"
                        iconSource: shellRoot.icon("night-light-symbolic")
                        isActive: qs.nightLightActive
                        activeColor: shellRoot.accentColor
                        onToggle: qs.setNightLight(!qs.nightLightActive)
                    }

                    // ── Auto-Brightness (placeholder) ──
                    ToggleListItem {
                        Layout.fillWidth: true
                        label: "Auto Brightness"
                        iconSource: shellRoot.icon("auto-brightness-symbolic")
                        isActive: qs.autoBrightnessActive
                        activeColor: shellRoot.accentColor
                        onToggle: qs.setAutoBrightness(!qs.autoBrightnessActive)
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
