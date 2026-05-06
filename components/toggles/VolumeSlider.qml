import QtQuick
import QtQuick.Controls

// VolumeSlider.qml — Pipewire audio volume slider.
// Context: shellRoot (icons), qs (audioNode), controlPanel (editMode)

Item {
    id: root
    property var modelData: parent ? parent.modelData : ({})

    Slider {
        anchors.centerIn: parent
        width: parent.width - 24
        height: 48
        from: 0; to: 100
        value: qs.audioNode ? qs.audioNode.volume * 100 : 50
        onMoved: {
            if (qs.audioNode) qs.audioNode.volume = value / 100.0
        }

        background: Rectangle {
            x: parent.leftPadding
            y: parent.topPadding + parent.availableHeight / 2 - height / 2
            implicitWidth: parent.parent.width; implicitHeight: 48
            width: parent.availableWidth; height: implicitHeight; radius: 24
            color: Qt.rgba(0, 0, 0, 0.2)
            Rectangle {
                width: parent.parent.visualPosition * (parent.width - height) + height
                height: parent.height; color: Qt.rgba(0.2, 0.5, 1.0, 1.0); radius: 24
            }
        }
        handle: Rectangle {
            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
            y: parent.topPadding + parent.availableHeight / 2 - height / 2
            implicitWidth: 48; implicitHeight: 48; radius: 24; color: "white"
            Image {
                anchors.centerIn: parent
                width: 22; height: 22
                sourceSize: Qt.size(24, 24)
                source: shellRoot.icon(qs.audioNode && qs.audioNode.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic")
            }
        }
    }

    // Block slider interaction during edit mode
    MouseArea {
        anchors.fill: parent
        enabled: controlPanel.editMode
    }
}
