import QtQuick
import QtQuick.Controls
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
        onMoved: qs.setBrightness(value)
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
    }

    // ── Vertical slider (1x2) ──
    Slider {
        id: vSlider
        anchors.fill: parent
        visible: root.isVertical
        orientation: Qt.Vertical
        from: 1; to: 100
        value: qs.brightnessValue
        onMoved: qs.setBrightness(value)
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
    }

    // Block slider interaction during edit mode
    MouseArea {
        anchors.fill: parent
        enabled: controlPanel.editMode
    }
}
