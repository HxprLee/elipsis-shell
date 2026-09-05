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

    // ── Security state ──
    property bool authVisible: false
    property real swipeOffset: 0
    property string wallpaperPath: ""

    // Brute-force protection
    property int failedAttempts: 0
    readonly property int maxAttempts: 10
    property bool lockedOut: false
    property int lockoutRemaining: 0

    // PAM lifecycle
    property bool pamReady: false
    property bool pamActive: false

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
                startPamSession()
            }
            swipeOffset = 0
        }
    }

    // ── Wallpaper ──
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

    // ── Lockout timer (progressive backoff) ──
    Timer {
        id: lockoutTimer
        interval: 1000
        repeat: true
        running: lockedOut
        onTriggered: {
            lockoutRemaining--
            if (lockoutRemaining <= 0) {
                lockedOut = false
                lockoutRemaining = 0
                restartPamAfterLockout()
            }
        }
    }

    function startPamSession() {
        if (lockedOut) return
        pamActive = true
        pam.active = true
    }

    function restartPamAfterLockout() {
        if (!authVisible) return
        pamActive = true
        pam.active = true
    }

    function handleFailedAttempt() {
        failedAttempts++
        passwordInput.text = ""
        pamReady = false
        pamActive = false

        if (failedAttempts >= maxAttempts) {
            lockedOut = true
            lockoutRemaining = calculateLockoutDuration()
            lockoutTimer.restart()
            pam.abort()
        } else {
            pam.active = false
            pam.active = true
            pamReady = false
        }
    }

    function calculateLockoutDuration() {
        let excess = failedAttempts - maxAttempts + 1
        if (excess <= 0) return 0
        // Exponential backoff: 2^(excess-1) minutes, capped at 60 min
        let seconds = Math.pow(2, Math.min(excess - 1, 6)) * 60
        return Math.min(Math.round(seconds), 3600)
    }

    // ── PAM Authentication ──
    PamContext {
        id: pam
        active: false

        onPamMessage: {
            if (responseRequired) {
                pamReady = true
            }
        }

        onCompleted: (result) => {
            pamReady = false
            pamActive = false
            if (result === PamResult.Success) {
                failedAttempts = 0
                lockedOut = false
                lockoutRemaining = 0
                lockoutTimer.stop()
                passwordInput.text = ""
                shellRoot.unlock()
            } else if (result === PamResult.MaxTries) {
                pamMessage.text = "Maximum attempts exceeded"
                pamMessage.isError = true
                handleFailedAttempt()
            } else {
                handleFailedAttempt()
            }
        }
    }

    function submitPassword() {
        if (lockedOut || !pamReady || passwordInput.text === "") return
        pamReady = false
        pam.respond(passwordInput.text)
    }

    function clearAuthState() {
        authVisible = false
        passwordInput.text = ""
        failedAttempts = 0
        lockedOut = false
        lockoutRemaining = 0
        lockoutTimer.stop()
        pamReady = false
        pamActive = false
        pam.abort()
    }

    // ── Main UI Layer (iPadOS Style) ──
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

            property string timeString: Qt.formatTime(new Date(), "h:mm")
            property string dateString: Qt.formatDate(new Date(), "dddd, MMMM d")
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: {
                    clockContainer.timeString = Qt.formatTime(new Date(), "h:mm");
                    clockContainer.dateString = Qt.formatDate(new Date(), "dddd, MMMM d");
                }
            }

            transform: Translate {
                y: swipeOffset * 1.2
                Behavior on y {
                    enabled: !lockMouseArea.pressed
                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                }
            }

            Text {
                text: clockContainer.dateString
                color: "white"
                font.pixelSize: 22
                font.weight: Font.DemiBold
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: clockContainer.timeString
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

    // ── Auth Layer ──
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
            spacing: 24
            Layout.alignment: Qt.AlignCenter

            scale: 0.9 + (parent.opacity * 0.1)
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

            // PAM status / error message
            Text {
                id: pamMessage
                anchors.horizontalCenter: parent.horizontalCenter
                property bool isError: false
                text: {
                    if (lockedOut) {
                        let m = Math.ceil(lockoutRemaining / 60)
                        let s = lockoutRemaining % 60
                        if (m > 0) return "Locked out. Try again in " + m + "m " + s + "s"
                        return "Locked out. Try again in " + s + "s"
                    }
                    if (pam.message !== "" && pam.message !== "Password: ")
                        return pam.message
                    if (isError) return pam.message
                    return "Enter Passcode"
                }
                color: isError ? "#ff4444" : (lockedOut ? "#ff8844" : "white")
                font.pixelSize: isError || lockedOut ? 16 : 22
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }

            // Password Field
            MaterialSurface {
                width: parent.width
                height: 56
                radius: 16
                enabled: !lockedOut

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
                    focus: authVisible && !lockedOut
                    activeFocusOnPress: true
                    enabled: !lockedOut
                    onAccepted: {
                        if (!lockedOut) submitPassword()
                    }
                }
            }

            // Numpad
            GridLayout {
                columns: 3
                rowSpacing: 20
                columnSpacing: 10
                width: parent.width
                Layout.alignment: Qt.AlignHCenter
                enabled: !lockedOut

                Repeater {
                    model: [
                        "1", "2", "3",
                        "4", "5", "6",
                        "7", "8", "9",
                        "Cancel", "0", "Enter"
                    ]
                    delegate: Button {
                        implicitWidth: 90
                        implicitHeight: 90
                        flat: true
                        enabled: !lockedOut
                        Accessible.name: modelData === "Cancel" ? "Cancel" : (modelData === "Enter" ? "Enter" : "Number " + modelData)
                        Accessible.role: Accessible.Button

                        background: MaterialSurface {
                            radius: 67
                            isActive: parent.pressed && !lockedOut
                        }

                        contentItem: Item {
                            anchors.fill: parent
                            Image {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                sourceSize: Qt.size(32, 32)
                                visible: modelData === "Cancel" || modelData === "Enter"
                                source: modelData === "Cancel"
                                    ? shellRoot.icon("window-close-symbolic")
                                    : (modelData === "Enter" ? shellRoot.icon("emblem-ok-symbolic") : "")
                            }
                            Text {
                                anchors.centerIn: parent
                                text: (modelData !== "Cancel" && modelData !== "Enter") ? modelData : ""
                                color: "white"
                                font.pixelSize: 28
                                font.weight: Font.Normal
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        onClicked: {
                            if (lockedOut) return
                            if (modelData === "Cancel") {
                                clearAuthState()
                            } else if (modelData === "Enter") {
                                submitPassword()
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
