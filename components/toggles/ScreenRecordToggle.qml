import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../reusables"
import ".."

Item {
    id: root
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Record"
    property string subtitleText: isRecording ? "Recording" : ""
    property string iconSource: shellRoot.icon(isRecording ? "media-playback-stop-symbolic" : "media-record-symbolic")
    property bool isActive: isRecording
    property color activeColor: Qt.rgba(1.0, 0.2, 0.2, 1.0)

    // Config properties
    property int audioIndex: 0 // 0: Desktop, 1: Mic, 2: Both, 3: None
    property var audioOptions: ["default_output", "default_input", "default_output|default_input", "none"]
    property var audioLabels: ["Desktop", "Microphone", "Both", "None"]

    property int fpsIndex: 2
    property var fpsOptions: ["30", "45", "60"]

    property int encoderIndex: 0
    property var encoderOptions: ["auto", "h264", "hevc", "av1"]
    property var encoderLabels: ["Auto", "H.264", "HEVC", "AV1"]

    property int resIndex: 0
    property var resOptions: ["0x0"]
    property var resLabels: ["Native"]

    property int bitrateIndex: 2
    property var bitrateOptions: ["medium", "high", "very_high", "ultra"]
    property var bitrateLabels: ["Medium", "High", "Very High", "Ultra"]

    property bool _loading: false

    function loadSettings() {
        if (!shellRoot.toggleDataLoaded) return;
        _loading = true;
        audioIndex = shellRoot.getToggleSetting("ScreenRecordToggle", "audioIndex", audioIndex)
        fpsIndex = shellRoot.getToggleSetting("ScreenRecordToggle", "fpsIndex", fpsIndex)
        encoderIndex = shellRoot.getToggleSetting("ScreenRecordToggle", "encoderIndex", encoderIndex)
        resIndex = shellRoot.getToggleSetting("ScreenRecordToggle", "resIndex", resIndex)
        bitrateIndex = shellRoot.getToggleSetting("ScreenRecordToggle", "bitrateIndex", bitrateIndex)
        _loading = false;
    }

    Connections {
        target: shellRoot
        function onToggleDataLoadedChanged() {
            if (shellRoot.toggleDataLoaded) {
                root.loadSettings();
            }
        }
    }

    // Load saved settings
    Component.onCompleted: {
        loadSettings();
    }

    // Save settings on change
    onAudioIndexChanged: { if (!_loading) shellRoot.setToggleSetting("ScreenRecordToggle", "audioIndex", audioIndex) }
    onFpsIndexChanged: { if (!_loading) shellRoot.setToggleSetting("ScreenRecordToggle", "fpsIndex", fpsIndex) }
    onEncoderIndexChanged: { if (!_loading) shellRoot.setToggleSetting("ScreenRecordToggle", "encoderIndex", encoderIndex) }
    onResIndexChanged: { if (!_loading) shellRoot.setToggleSetting("ScreenRecordToggle", "resIndex", resIndex) }
    onBitrateIndexChanged: { if (!_loading) shellRoot.setToggleSetting("ScreenRecordToggle", "bitrateIndex", bitrateIndex) }

    property bool isRecording: recordProc.running

    function toggleRecording() {
        if (isRecording) {
            stopProc.running = true
        } else {
            let aOpt = audioOptions[audioIndex]
            let aStr = aOpt !== "none" ? `-a "${aOpt}"` : ""
            let cmd = `gpu-screen-recorder -w screen ${aStr} -f ${fpsOptions[fpsIndex]} -k ${encoderOptions[encoderIndex]} -s ${resOptions[resIndex]} -q ${bitrateOptions[bitrateIndex]} -o ~/Videos/ScreenRecord-$(date +%Y%m%d-%H%M%S).mp4`

            recordProc.command = ["sh", "-c", cmd]
            recordProc.running = true
        }
    }

    signal toggled()
    onToggled: toggleRecording()

    Process {
        id: recordProc
        command: []
        running: false
    }

    Process {
        id: stopProc
        command: ["pkill", "-SIGINT", "-f", "gpu-screen-recorder.*-o"]
        running: false
    }

    property bool hasExpandedView: true
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot
            implicitHeight: contentLayout.implicitHeight

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                spacing: 16

                ExpandedHeader {
                    Layout.fillWidth: true
                    toggle: root
                    showButton: true
                    buttonText: root.isRecording ? "Stop" : "Record"
                    buttonIconSource: shellRoot.icon(root.isRecording ? "media-playback-stop-symbolic" : "media-record-symbolic")
                    isButtonActive: root.isRecording
                    onButtonClicked: root.toggleRecording()
                }

                // Option Rows
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: 12
                    spacing: 16

                    // Audio
                    RowLayout {
                        spacing: 8
                        Text { text: "Audio Source"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 15; Layout.fillWidth: true }
                        TouchComboBox {
                            Layout.alignment: Qt.AlignRight
                            model: root.audioLabels
                            currentIndex: root.audioIndex
                            activeColor: root.activeColor
                            onActivated: root.audioIndex = currentIndex
                        }
                    }

                    // FPS
                    RowLayout {
                        spacing: 8
                        Text { text: "FPS"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 15; Layout.fillWidth: true }
                        TouchComboBox {
                            Layout.alignment: Qt.AlignRight
                            model: root.fpsOptions
                            currentIndex: root.fpsIndex
                            activeColor: root.activeColor
                            onActivated: root.fpsIndex = currentIndex
                        }
                    }

                    // Resolution
                    RowLayout {
                        spacing: 8
                        Text { text: "Resolution"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 15; Layout.fillWidth: true }
                        TouchComboBox {
                            Layout.alignment: Qt.AlignRight
                            model: root.resLabels
                            currentIndex: root.resIndex
                            activeColor: root.activeColor
                            onActivated: root.resIndex = currentIndex
                        }
                    }

                    // Encoder
                    RowLayout {
                        spacing: 8
                        Text { text: "Encoder"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 15; Layout.fillWidth: true }
                        TouchComboBox {
                            Layout.alignment: Qt.AlignRight
                            model: root.encoderLabels
                            currentIndex: root.encoderIndex
                            activeColor: root.activeColor
                            onActivated: root.encoderIndex = currentIndex
                        }
                    }

                    // Quality / Bitrate
                    RowLayout {
                        spacing: 8
                        Text { text: "Quality"; color: Qt.rgba(1, 1, 1, 0.8); font.pixelSize: 15; Layout.fillWidth: true }
                        TouchComboBox {
                            Layout.alignment: Qt.AlignRight
                            model: root.bitrateLabels
                            currentIndex: root.bitrateIndex
                            activeColor: root.activeColor
                            onActivated: root.bitrateIndex = currentIndex
                        }
                    }
                }
            }
        }
    }
}
