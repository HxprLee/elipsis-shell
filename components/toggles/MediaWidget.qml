import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris

// MediaWidget.qml — MPRIS media player with album art, playback controls,
// and an iOS-style expanded view with large artwork, progress bar, and transport controls.

Item {
    id: root
    property bool isControlWidget: true
    property var modelData: parent ? parent.modelData : ({})
    property var activePlayer: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    property string toggleName: "Media Control"

    property var availableSizes: [
        { colSpan: 2, rowSpan: 2 },
        { colSpan: 4, rowSpan: 2 }
    ]

    property bool is4x2: modelData ? modelData.colSpan === 4 : false

    // Helper functions
    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00"
        let mins = Math.floor(seconds / 60)
        let secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    // Position tracker — emit positionChanged every second for reactive updates
    Timer {
        running: activePlayer && activePlayer.isPlaying && (is4x2 || expandedOverlay.isExpanded)
        interval: 1000
        repeat: true
        onTriggered: if (activePlayer) activePlayer.positionChanged()
    }

    // ── Expanded view support ──
    property bool hasExpandedView: true
    property int expandedHeight: 580
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot
            property var player: root.activePlayer
            implicitHeight: layout.implicitHeight

            ColumnLayout {
                id: layout
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                // ── Large Album Art (iOS style) ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 20

                    Rectangle {
                        id: artCard
                        anchors.centerIn: parent
                        width: parent.width
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
                                  ? root.formatTime(expandedRoot.player.position) : "0:00"
                            color: Qt.rgba(1, 1, 1, 0.45)
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: expandedRoot.player && expandedRoot.player.lengthSupported
                                  ? "-" + root.formatTime(expandedRoot.player.length - expandedRoot.player.position) : "-0:00"
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
                            id: expandedPrevIcon
                            anchors.centerIn: parent
                            source: shellRoot.icon("media-skip-backward-symbolic")
                            sourceSize: Qt.size(28, 28)
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: expandedPrevIcon
                            source: expandedPrevIcon
                            color: "white"
                        }
                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            enabled: expandedRoot.player && (expandedRoot.player.canGoPrevious ?? false)
                            onClicked: expandedRoot.player.previous()
                        }
                    }

                    Item { Layout.preferredWidth: 32 }

                    // Play/Pause
                    Item {
                        width: 64; height: 64
                        opacity: expandedRoot.player && (expandedRoot.player.canTogglePlaying ?? false) ? 1.0 : 0.3

                        Image {
                            id: expandedPlayIcon
                            anchors.centerIn: parent
                            source: shellRoot.icon(
                                expandedRoot.player && expandedRoot.player.isPlaying
                                    ? "media-playback-pause-symbolic"
                                    : "media-playback-start-symbolic"
                            )
                            sourceSize: Qt.size(48, 48)
                            visible: false
                        }
                        
                        ColorOverlay {
                            anchors.fill: expandedPlayIcon
                            source: expandedPlayIcon
                            color: "white"
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
                            id: expandedNextIcon
                            anchors.centerIn: parent
                            source: shellRoot.icon("media-skip-forward-symbolic")
                            sourceSize: Qt.size(28, 28)
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: expandedNextIcon
                            source: expandedNextIcon
                            color: "white"
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
        id: compactBgImg
        anchors.fill: parent
        source: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
        fillMode: Image.PreserveAspectCrop
        visible: false // Hidden, used as source for blur
    }

    FastBlur {
        anchors.fill: parent
        source: compactBgImg
        radius: 64
        visible: compactBgImg.status === Image.Ready
    }

    // Fallback when no art
    Image {
        anchors.centerIn: parent
        visible: !activePlayer || !activePlayer.trackArtUrl
        source: shellRoot.icon("multimedia-audio-player-symbolic")
        sourceSize: Qt.size(64, 64)
        opacity: 0.15
    }

    // Dark overlay for readability
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)
    }

    // ── 2x2 Compact Layout ──
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        visible: !root.is4x2
        spacing: 0

        // Header: Art + Text
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Thumbnail Art
            Rectangle {
                width: 48; height: 48; radius: 10
                color: Qt.rgba(1, 1, 1, 0.1)
                clip: true

                Image {
                    anchors.fill: parent
                    source: compactBgImg.source
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                }
                
                Image {
                    anchors.centerIn: parent
                    visible: parent.children[0].status !== Image.Ready
                    source: shellRoot.icon("multimedia-audio-player-symbolic")
                    sourceSize: Qt.size(24, 24)
                    opacity: 0.4
                }
            }

            // Info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: activePlayer ? (activePlayer.trackTitle || "Unknown Title") : "No Media"
                    color: "white"
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: activePlayer ? (activePlayer.trackArtist || "Unknown Artist") : ""
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: activePlayer !== null
                }
            }
        }

        Item { Layout.fillHeight: true } // spacer

        // Transport Controls
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            spacing: 24

            Item {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                opacity: activePlayer && (activePlayer.canGoPrevious ?? false) ? 1.0 : 0.4
                Image {
                    id: skipBackIcon2x2
                    anchors.fill: parent
                    source: shellRoot.icon("media-skip-backward-symbolic")
                    sourceSize: Qt.size(24, 24)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: skipBackIcon2x2
                    source: skipBackIcon2x2
                    color: "white"
                }
                MouseArea { anchors.fill: parent; enabled: !controlPanel.editMode && !!activePlayer && (activePlayer.canGoPrevious ?? false); onClicked: activePlayer.previous() }
            }
            Rectangle {
                width: 44; height: 44; radius: 22
                color: "white" // iOS 18 style solid white for primary action
                opacity: activePlayer && (activePlayer.canTogglePlaying ?? false) ? 1.0 : 0.4
                Image {
                    id: playIcon2x2
                    anchors.centerIn: parent
                    source: shellRoot.icon(activePlayer && activePlayer.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                    sourceSize: Qt.size(24, 24)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: playIcon2x2
                    source: playIcon2x2
                    color: "black"
                }
                scale: playArea2x2.pressed ? 0.9 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }
                MouseArea { id: playArea2x2; anchors.fill: parent; enabled: !controlPanel.editMode && !!activePlayer && (activePlayer.canTogglePlaying ?? false); onClicked: activePlayer.togglePlaying() }
            }
            Item {
                Layout.preferredWidth: 24; Layout.preferredHeight: 24
                opacity: activePlayer && (activePlayer.canGoNext ?? false) ? 1.0 : 0.4
                Image {
                    id: skipFwdIcon2x2
                    anchors.fill: parent
                    source: shellRoot.icon("media-skip-forward-symbolic")
                    sourceSize: Qt.size(24, 24)
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: skipFwdIcon2x2
                    source: skipFwdIcon2x2
                    color: "white"
                }
                MouseArea { anchors.fill: parent; enabled: !controlPanel.editMode && !!activePlayer && (activePlayer.canGoNext ?? false); onClicked: activePlayer.next() }
            }
        }
    }

    // ── 4x2 iOS 18 Style Layout ──
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14 // slightly tighter margins to maximize art size
        visible: root.is4x2
        spacing: 16

        // Left: Large Album Art
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: height
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.1)
            clip: true

            Image {
                anchors.fill: parent
                source: compactBgImg.source
                fillMode: Image.PreserveAspectCrop
                visible: source !== ""
            }
            
            Image {
                anchors.centerIn: parent
                visible: parent.children[0].status !== Image.Ready
                source: shellRoot.icon("multimedia-audio-player-symbolic")
                sourceSize: Qt.size(32, 32)
                opacity: 0.4
            }
        }

        // Right: Content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Top row: Text
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: activePlayer ? (activePlayer.trackTitle || "Unknown Title") : "No Media"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: activePlayer ? (activePlayer.trackArtist || "Unknown Artist") : ""
                        color: Qt.rgba(1, 1, 1, 0.7)
                        font.pixelSize: 14
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: activePlayer !== null
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

                    Item {
                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                        opacity: activePlayer && (activePlayer.canGoPrevious ?? false) ? 1.0 : 0.4
                        scale: skipBackArea.pressed ? 0.8 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Image {
                            id: skipBackIcon4x2
                            anchors.fill: parent
                            source: shellRoot.icon("media-skip-backward-symbolic")
                            sourceSize: Qt.size(24, 24)
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: skipBackIcon4x2
                            source: skipBackIcon4x2
                            color: "white"
                        }
                        MouseArea { id: skipBackArea; anchors.fill: parent; anchors.margins: -8; enabled: !controlPanel.editMode && !!activePlayer && (activePlayer.canGoPrevious ?? false); onClicked: activePlayer.previous() }
                    }

                    Item {
                        Layout.preferredWidth: 32; Layout.preferredHeight: 32
                        opacity: activePlayer && (activePlayer.canTogglePlaying ?? false) ? 1.0 : 0.4
                        scale: playArea4x2.pressed ? 0.8 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Image {
                            id: playIcon4x2
                            anchors.fill: parent
                            source: shellRoot.icon(activePlayer && activePlayer.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                            sourceSize: Qt.size(32, 32)
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: playIcon4x2
                            source: playIcon4x2
                            color: "white"
                        }
                        MouseArea { id: playArea4x2; anchors.fill: parent; anchors.margins: -12; enabled: !controlPanel.editMode && !!activePlayer && (activePlayer.canTogglePlaying ?? false); onClicked: activePlayer.togglePlaying() }
                    }

                    Item {
                        Layout.preferredWidth: 24; Layout.preferredHeight: 24
                        opacity: activePlayer && (activePlayer.canGoNext ?? false) ? 1.0 : 0.4
                        scale: skipFwdArea.pressed ? 0.8 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Image {
                            id: skipFwdIcon4x2
                            anchors.fill: parent
                            source: shellRoot.icon("media-skip-forward-symbolic")
                            sourceSize: Qt.size(24, 24)
                            visible: false
                        }
                        ColorOverlay {
                            anchors.fill: skipFwdIcon4x2
                            source: skipFwdIcon4x2
                            color: "white"
                        }
                        MouseArea { id: skipFwdArea; anchors.fill: parent; anchors.margins: -8; enabled: !controlPanel.editMode && !!activePlayer && (activePlayer.canGoNext ?? false); onClicked: activePlayer.next() }
                    }
                }

                Item { Layout.fillWidth: true } // Push right
            }

            Item { Layout.fillHeight: true } // Spacer

            // Bottom row: Progress Bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: activePlayer !== null

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
                            if (!activePlayer || !activePlayer.lengthSupported || activePlayer.length <= 0) return 0
                            return Math.min(1.0, activePlayer.position / activePlayer.length) * parent.width
                        }
                        height: parent.height
                        radius: 2
                        color: "white"
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }

                    // Scrubber interaction
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: activePlayer && (activePlayer.canSeek ?? false)
                        onClicked: function(mouse) {
                            if (activePlayer && activePlayer.lengthSupported) {
                                let ratio = Math.max(0, Math.min(1.0, mouse.x / parent.width))
                                activePlayer.position = ratio * activePlayer.length
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: activePlayer && activePlayer.positionSupported ? root.formatTime(activePlayer.position) : "0:00"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: activePlayer && activePlayer.lengthSupported ? "-" + root.formatTime(activePlayer.length - activePlayer.position) : "-0:00"
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
