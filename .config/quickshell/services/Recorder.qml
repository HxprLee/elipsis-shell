pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Recorder singleton — gpu-screen-recorder lifecycle.
// Owns isScreenRecording flag. Stops via pkill -SIGINT.

QtObject {
    id: recorder

    property bool isScreenRecording: screenRecordProc.running

    Process {
        id: screenRecordProc
        running: false
    }
    Process {
        id: stopScreenRecordProc
        command: ["pkill", "-SIGINT", "-f", "gpu-screen-recorder.*-o"]
        running: false
    }

    function toggleScreenRecording(audioIndex, fpsIndex, encoderIndex, resIndex, bitrateIndex) {
        if (recorder.isScreenRecording) {
            stopScreenRecordProc.running = true;
        } else {
            let audioOptions = ["default_output", "default_input", "default_output|default_input", "none"];
            let fpsOptions = ["30", "45", "60"];
            let encoderOptions = ["auto", "h264", "hevc", "av1"];
            let resOptions = ["0x0"];
            let bitrateOptions = ["medium", "high", "very_high", "ultra"];

            // Clamp indices to valid range to defend against corrupted persisted state.
            let aIdx = Math.max(0, Math.min(audioOptions.length - 1, parseInt(audioIndex) || 0));
            let fIdx = Math.max(0, Math.min(fpsOptions.length - 1, parseInt(fpsIndex) || 0));
            let eIdx = Math.max(0, Math.min(encoderOptions.length - 1, parseInt(encoderIndex) || 0));
            let rIdx = Math.max(0, Math.min(resOptions.length - 1, parseInt(resIndex) || 0));
            let bIdx = Math.max(0, Math.min(bitrateOptions.length - 1, parseInt(bitrateIndex) || 0));

            let aOpt = audioOptions[aIdx];
            let aStr = aOpt !== "none" ? `-a "${aOpt}"` : "";
            let cmd = `gpu-screen-recorder -w screen ${aStr} -f ${fpsOptions[fIdx]} -k ${encoderOptions[eIdx]} -s ${resOptions[rIdx]} -q ${bitrateOptions[bIdx]} -o ~/Videos/ScreenRecord-$(date +%Y%m%d-%H%M%S).mp4`;

            screenRecordProc.command = ["sh", "-c", cmd];
            screenRecordProc.running = true;
        }
    }
}
