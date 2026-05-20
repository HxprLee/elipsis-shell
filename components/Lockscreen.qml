import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

WlSessionLockSurface {
    id: root
    
    // Background with conditional blur
    Rectangle {
        anchors.fill: parent
        color: "#050505"
        
        Image {
            id: bgImage
            anchors.fill: parent
            source: root.wallpaperPath
            fillMode: Image.PreserveAspectCrop
            visible: false
            onStatusChanged: {
                if (status === Image.Error) console.error("Lockscreen failed to load wallpaper:", source)
            }
        }

        ShaderEffectSource {
            id: bgSource
            anchors.fill: parent
            sourceItem: bgImage
            live: true
            hideSource: true
        }

        FastBlur {
            anchors.fill: parent
            source: bgSource
            radius: Math.min(80, 80 * (authVisible ? 1 : Math.abs(swipeOffset) / 150))
            opacity: 1.0
            visible: shellRoot.blurEnabled
        }
        
        // Darken overlay
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.2 + (0.4 * (authVisible ? 1 : Math.abs(swipeOffset) / 150))
        }
    }

    MouseArea {
        id: lockMouseArea
        anchors.fill: parent
        property real startY: 0
        preventStealing: true
        onPressed: (mouse) => startY = mouse.y
        onPositionChanged: (mouse) => {
            if (!authVisible) {
                swipeOffset = Math.min(0, mouse.y - startY)
            }
        }
        onReleased: (mouse) => {
            if (!authVisible && (startY - mouse.y) > 150) {
                authVisible = true
            }
            swipeOffset = 0
        }
    }

    property bool authVisible: false
    property real swipeOffset: 0
    property string wallpaperPath: ""

    Process {
        id: wallpaperQuery
        command: ["awww", "query"]
        stdout: SplitParser {
            onRead: (line) => {
                let match = line.match(/image: (.*)/);
                if (match) {
                    root.wallpaperPath = "file://" + match[1].trim();
                }
            }
        }
    }

    Component.onCompleted: {
        wallpaperQuery.running = true;
    }

    PamContext {
        id: pam
        active: authVisible
        onCompleted: (result) => {
            if (result === PamResult.Success) {
                shellRoot.unlock()
            } else {
                passwordInput.text = ""
            }
        }
    }

    // --- Main UI Layer (iPadOS Style) ---
    Item {
        anchors.fill: parent
        opacity: 1 - Math.min(1, authVisible ? 1 : (Math.abs(swipeOffset) / 150))
        visible: opacity > 0
        
        // Padlock Icon
        Image {
            id: padlockIcon
            source: shellRoot.icon("system-lock-screen-symbolic")
            width: 32; height: 32
            anchors.top: parent.top
            anchors.topMargin: 48
            anchors.horizontalCenter: parent.horizontalCenter
            sourceSize: Qt.size(32, 32)
            opacity: 0.9
            
            transform: Translate {
                y: swipeOffset * 0.5
                Behavior on y {
                    enabled: !lockMouseArea.pressed
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
        }

        // Center Clock (iPadOS style: Date above, huge clock)
        Column {
            id: clockContainer
            anchors.top: padlockIcon.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -15
            
            transform: Translate {
                y: swipeOffset * 1.2
                Behavior on y {
                    enabled: !lockMouseArea.pressed
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }
            
            Text {
                text: Qt.formatDate(new Date(), "dddd, MMMM d")
                color: "white"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: Qt.formatTime(new Date(), "h:mm")
                color: "white"
                font.pixelSize: 100
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Swipe up indicator (Home bar)
        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12
            opacity: 1 - Math.min(1, authVisible ? 1 : (Math.abs(swipeOffset) / 150))
            
            transform: Translate {
                y: swipeOffset * 0.3
                Behavior on y {
                    enabled: !lockMouseArea.pressed
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }

            Text {
                text: "Swipe up to unlock"
                color: "white"
                font.pixelSize: 15
                font.weight: Font.Medium
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: 140
                height: 5
                radius: 2.5
                color: "white"
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // --- Auth Layer ---
    Item {
        id: authLayer
        anchors.fill: parent
        opacity: authVisible ? 1 : Math.min(1, Math.abs(swipeOffset) / 150)
        visible: opacity > 0
        
        Behavior on opacity {
            enabled: !lockMouseArea.pressed
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        Column {
            anchors.centerIn: parent
            width: 320
            spacing: 32
            
            scale: 0.9 + (parent.opacity * 0.1)
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: pam.message !== "" ? pam.message : "Enter Passcode"
                color: pam.messageIsError ? "#ff4444" : "white"
                font.pixelSize: 22
                font.weight: Font.Medium
            }

            // Password Field
            Rectangle {
                width: parent.width
                height: 56
                radius: 16
                color: Qt.rgba(1, 1, 1, 0.15)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    color: "white"
                    font.pixelSize: 24
                    echoMode: pam.responseVisible ? TextInput.Normal : TextInput.Password
                    focus: authVisible
                    onAccepted: {
                        pam.respond(text)
                        text = ""
                    }
                }
            }

            // Numpad
            GridLayout {
                columns: 3
                rowSpacing: 20
                columnSpacing: 24
                width: parent.width
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Cancel", "0", "OK"]
                    delegate: Button {
                        implicitWidth: 80
                        implicitHeight: 80
                        flat: true
                        
                        background: Rectangle {
                            radius: 40
                            color: parent.pressed ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.15)
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            border.width: 1
                            visible: modelData !== "Cancel" && modelData !== "OK"
                        }

                        contentItem: Text {
                            text: modelData
                            color: "white"
                            font.pixelSize: (modelData === "Cancel" || modelData === "OK") ? 18 : 32
                            font.weight: (modelData === "Cancel" || modelData === "OK") ? Font.Medium : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            if (modelData === "Cancel") {
                                authVisible = false
                                passwordInput.text = ""
                            } else if (modelData === "OK") {
                                pam.respond(passwordInput.text)
                                passwordInput.text = ""
                            } else {
                                passwordInput.text += modelData
                            }
                        }
                    }
                }
            }
        }
    }

    // Custom Top Bar for Lockscreen (hide clock since we have big clock)
    Item {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 40
        anchors.margins: 16
        opacity: 1 - Math.min(1, authVisible ? 1 : (Math.abs(swipeOffset) / 150))
        visible: opacity > 0
        
        Behavior on opacity {
            enabled: !lockMouseArea.pressed
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        StatusCluster {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: "white"
            batteryPct: shellRoot.batteryPct
            batteryStatus: shellRoot.batteryStatus
        }
    }
}
