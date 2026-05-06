import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// MediaWidget.qml — MPRIS media player with album art, playback controls,
// and an iOS-style expanded view with large artwork, progress bar, and transport controls.

Item {
    id: root
    property var modelData: parent ? parent.modelData : ({})
    property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    property string titleText: "Media Control"

    // ── Expanded view support ──
    property bool hasExpandedView: true
    property int expandedHeight: 520
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot
            property var player: root.activePlayer

            // Helper functions
            function formatTime(seconds) {
                if (!seconds || seconds < 0) return "0:00"
                let mins = Math.floor(seconds / 60)
                let secs = Math.floor(seconds % 60)
                return mins + ":" + (secs < 10 ? "0" : "") + secs
            }

            // Position tracker — emit positionChanged every second for reactive updates
            Timer {
                running: expandedRoot.player && expandedRoot.player.isPlaying && expandedOverlay.isExpanded
                interval: 1000
                repeat: true
                onTriggered: if (expandedRoot.player) expandedRoot.player.positionChanged()
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ── Large Album Art (iOS style) ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(parent.width - 32, 240)
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 20

                    Rectangle {
                        id: artCard
                        anchors.centerIn: parent
                        width: Math.min(parent.width, 240)
                        height: width
                        radius: 16
                        color: Qt.rgba(1, 1, 1, 0.05)
                        clip: true

                        Image {
                            id: albumArt
                            anchors.fill: parent
                            source: expandedRoot.player ? (expandedRoot.player.trackArtUrl || "") : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: source !== ""
                        }

                        // Fallback icon
                        Image {
                            anchors.centerIn: parent
                            visible: !albumArt.visible || albumArt.status !== Image.Ready
                            source: shellRoot.icon("multimedia-audio-player-symbolic")
                            sourceSize: Qt.size(64, 64)
                            opacity: 0.3
                        }

                        // Subtle scale animation when playing
                        scale: expandedRoot.player && expandedRoot.player.isPlaying ? 1.0 : 0.92
                        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }

                // ── Song Info ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    // Track title (marquee-like, bold, larger)
                    Text {
                        text: expandedRoot.player ? (expandedRoot.player.trackTitle || "Not Playing") : "No Media"
                        color: "white"
                        font.pixelSize: 20
                        font.bold: true
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    // Artist name
                    Text {
                        text: expandedRoot.player ? (expandedRoot.player.trackArtist || "Unknown Artist") : ""
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.pixelSize: 16
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: expandedRoot.player !== null
                    }
                }

                Item { Layout.preferredHeight: 16 }

                // ── Progress Bar (iOS style) ──
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: expandedRoot.player !== null

                    // Scrubber track
                    Item {
                        Layout.fillWidth: true
                        height: 6

                        // Background track
                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: Qt.rgba(1, 1, 1, 0.15)
                        }

                        // Progress fill
                        Rectangle {
                            width: {
                                if (!expandedRoot.player || !expandedRoot.player.lengthSupported || expandedRoot.player.length <= 0)
                                    return 0
                                return Math.min(1.0, expandedRoot.player.position / expandedRoot.player.length) * parent.width
                            }
                            height: parent.height
                            radius: 3
                            color: "white"
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }

                        // Seek interaction
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            enabled: expandedRoot.player && (expandedRoot.player.canSeek ?? false)
                            onClicked: function(mouse) {
                                if (expandedRoot.player && expandedRoot.player.lengthSupported) {
                                    let ratio = Math.max(0, Math.min(1.0, mouse.x / parent.width))
                                    expandedRoot.player.position = ratio * expandedRoot.player.length
                                }
                            }
                        }
                    }

                    // Time labels
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: expandedRoot.player && expandedRoot.player.positionSupported
                                  ? expandedRoot.formatTime(expandedRoot.player.position) : "0:00"
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: expandedRoot.player && expandedRoot.player.lengthSupported
                                  ? "-" + expandedRoot.formatTime(expandedRoot.player.length - expandedRoot.player.position) : "-0:00"
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }

                Item { Layout.preferredHeight: 8 }

                // ── Transport Controls (iOS style — large centered play, skip on sides) ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0

                    Item { Layout.fillWidth: true }

                    // Previous
                    Item {
                        width: 48; height: 48
                        opacity: expandedRoot.player && (expandedRoot.player.canGoPrevious ?? false) ? 1.0 : 0.3
                        scale: prevArea.pressed ? 0.85 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Image {
                            anchors.centerIn: parent
                            source: shellRoot.icon("media-skip-backward-symbolic")
                            sourceSize: Qt.size(28, 28)
                        }
                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            enabled: expandedRoot.player && (expandedRoot.player.canGoPrevious ?? false)
                            onClicked: expandedRoot.player.previous()
                        }
                    }

                    Item { Layout.preferredWidth: 32 }

                    // Play/Pause (large circular button)
                    Rectangle {
                        width: 64; height: 64; radius: 32
                        color: "white"
                        opacity: expandedRoot.player && (expandedRoot.player.canTogglePlaying ?? false) ? 1.0 : 0.3

                        Image {
                            anchors.centerIn: parent
                            source: shellRoot.icon(
                                expandedRoot.player && expandedRoot.player.isPlaying
                                    ? "media-playback-pause-symbolic"
                                    : "media-playback-start-symbolic"
                            )
                            sourceSize: Qt.size(32, 32)
                            // Invert color for white button
                        }

                        scale: playArea.pressed ? 0.9 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        MouseArea {
                            id: playArea
                            anchors.fill: parent
                            enabled: expandedRoot.player && (expandedRoot.player.canTogglePlaying ?? false)
                            onClicked: expandedRoot.player.togglePlaying()
                        }
                    }

                    Item { Layout.preferredWidth: 32 }

                    // Next
                    Item {
                        width: 48; height: 48
                        opacity: expandedRoot.player && (expandedRoot.player.canGoNext ?? false) ? 1.0 : 0.3
                        Image {
                            anchors.centerIn: parent
                            source: shellRoot.icon("media-skip-forward-symbolic")
                            sourceSize: Qt.size(28, 28)
                        }
                        scale: nextArea.pressed ? 0.85 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            enabled: expandedRoot.player && (expandedRoot.player.canGoNext ?? false)
                            onClicked: expandedRoot.player.next()
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Item { Layout.preferredHeight: 8 }

                // ── Bottom row: volume / player identity ──
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Player identity pill
                    Rectangle {
                        height: 28
                        width: playerIdRow.width + 20
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.1)

                        RowLayout {
                            id: playerIdRow
                            anchors.centerIn: parent
                            spacing: 6

                            Image {
                                source: shellRoot.icon("multimedia-audio-player-symbolic")
                                sourceSize: Qt.size(14, 14)
                            }

                            Text {
                                text: expandedRoot.player ? (expandedRoot.player.identity || "Player") : "No Player"
                                color: Qt.rgba(1, 1, 1, 0.7)
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (expandedRoot.player && (expandedRoot.player.canRaise ?? false)) expandedRoot.player.raise()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Volume slider (small inline)
                    RowLayout {
                        spacing: 6
                        visible: expandedRoot.player && (expandedRoot.player.volumeSupported ?? false)

                        Image {
                            source: shellRoot.icon("audio-volume-medium-symbolic")
                            sourceSize: Qt.size(14, 14)
                            opacity: 0.6
                        }

                        Item {
                            width: 80; height: 4

                            Rectangle {
                                anchors.fill: parent
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.15)
                            }

                            Rectangle {
                                width: expandedRoot.player ? expandedRoot.player.volume * parent.width : 0
                                height: parent.height
                                radius: 2
                                color: Qt.rgba(1, 1, 1, 0.6)
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                onClicked: function(mouse) {
                                    if (expandedRoot.player && expandedRoot.player.volumeSupported) {
                                        expandedRoot.player.volume = Math.max(0, Math.min(1.0, mouse.x / parent.width))
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // "No media" empty state
            Text {
                anchors.centerIn: parent
                visible: !expandedRoot.player
                text: "No media playing"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.pixelSize: 18
            }
        }
    }

    // ── Compact widget view (shown in the grid) ──
    Image {
        anchors.fill: parent
        source: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
        fillMode: Image.PreserveAspectCrop
        visible: source !== ""
    }

    // Fallback when no art
    Image {
        anchors.centerIn: parent
        visible: !activePlayer || !activePlayer.trackArtUrl
        source: shellRoot.icon("multimedia-audio-player-symbolic")
        sourceSize: Qt.size(32, 32)
        opacity: 0.4
    }

    // Dark overlay for readability
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 4

        Text {
            text: activePlayer ? (activePlayer.trackTitle || "Unknown Title") : "No Media"
            color: "white"
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: activePlayer ? (activePlayer.trackArtist || "Unknown Artist") : ""
            color: Qt.rgba(1, 1, 1, 0.7)
            font.pixelSize: 13
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible: activePlayer !== null
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Image {
                source: shellRoot.icon("media-skip-backward-symbolic")
                sourceSize: Qt.size(24, 24)
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                opacity: activePlayer && (activePlayer.canGoPrevious ?? false) ? 1.0 : 0.3
                MouseArea { anchors.fill: parent; enabled: !controlPanel.editMode && !!activePlayer && (activePlayer.canGoPrevious ?? false); onClicked: activePlayer.previous() }
            }
            Rectangle {
                width: 44; height: 44; radius: 22
                color: Qt.rgba(1, 1, 1, 0.2)
                Image {
                    anchors.centerIn: parent
                    source: shellRoot.icon(activePlayer && activePlayer.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                    sourceSize: Qt.size(24, 24)
                }
                MouseArea { anchors.fill: parent; enabled: !controlPanel.editMode && !!activePlayer; onClicked: activePlayer.togglePlaying() }
            }
            Image {
                source: shellRoot.icon("media-skip-forward-symbolic")
                sourceSize: Qt.size(24, 24)
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                opacity: activePlayer && (activePlayer.canGoNext ?? false) ? 1.0 : 0.3
                MouseArea { anchors.fill: parent; enabled: !controlPanel.editMode && !!activePlayer && (activePlayer.canGoNext ?? false); onClicked: activePlayer.next() }
            }
        }
    }
}
