import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

// VolumeSlider.qml — Pipewire audio volume slider.
// Context: shellRoot (icons), qs (audioNode), controlPanel (editMode)

Item {
    id: root
    property var modelData: parent ? parent.modelData : ({})

    property var availableSizes: [
        { colSpan: 2, rowSpan: 1 },
        { colSpan: 4, rowSpan: 1 }
    ]

    property alias isPressed: slider.pressed

    Slider {
        id: slider
        anchors.fill: parent
        from: 0; to: 100
        value: qs.audioNode ? qs.audioNode.volume * 100 : 50
        onMoved: {
            if (qs.audioNode) qs.audioNode.volume = value / 100.0
        }
        padding: 0

        background: Rectangle {
            id: bgTrack
            anchors.fill: parent
            radius: 0
            color: Qt.rgba(1, 1, 1, 0.15)
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

            Rectangle {
                width: slider.visualPosition * bgTrack.width
                height: bgTrack.height
                radius: 0
                color: Qt.rgba(0.2, 0.5, 1.0, 1.0)
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
                        color: "white"
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
