pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Brightness singleton — owns backlight detection (intel_backlight /
// amdgpu_bl0 / ...) + read/write via /sys/class/backlight and login1 D-Bus.
// Also owns keyboard backlight (dell::kbd_backlight) + dark mode (gsettings).

Item {
    id: brightness

    // ── Display backlight ──
    property int brightnessValue: 50
    property int maxBrightness: 100
    property string backlightDevice: ""
    property var backlightCandidates: ["intel_backlight", "amdgpu_bl0", "acpi_video0", "nv_backlight", "apple_backlight", "panasonic_backlight", "sony_backlight"]
    property int backlightProbeIndex: 0

    function detectBacklightDevice() {
        if (brightness.backlightDevice !== "") return;
        if (brightness.backlightProbeIndex >= brightness.backlightCandidates.length) return;
        let d = brightness.backlightCandidates[brightness.backlightProbeIndex];
        testDeviceProc.command = ["test", "-r", "/sys/class/backlight/" + d + "/brightness"];
        testDeviceProc.deviceName = d;
        testDeviceProc.running = true;
    }

    Component.onCompleted: {
        detectBacklightDevice();
    }

    Process {
        id: testDeviceProc
        property string deviceName: ""
        running: false
        onExited: (code) => {
            if (code === 0) {
                maxBrightnessProc.running = true;
                brightnessProc.running = true;
            } else {
                brightness.backlightProbeIndex++;
                brightness.detectBacklightDevice();
            }
        }
    }

    Process {
        id: maxBrightnessProc
        command: ["cat", "/sys/class/backlight/" + brightness.backlightDevice + "/max_brightness"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let v = parseInt(data.trim());
                if (!isNaN(v)) brightness.maxBrightness = v;
            }
        }
    }

    Process {
        id: brightnessProc
        command: ["cat", "/sys/class/backlight/" + brightness.backlightDevice + "/brightness"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let v = parseInt(data.trim());
                if (!isNaN(v) && brightness.maxBrightness > 0)
                    brightness.brightnessValue = Math.round((v / brightness.maxBrightness) * 100);
            }
        }
    }

    Process {
        id: setBrightnessProc
        running: false
    }

    function setBrightness(pct) {
        brightnessValue = pct;
        let raw = Math.round((pct / 100.0) * maxBrightness);
        setBrightnessProc.command = ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", backlightDevice, String(raw)];
        setBrightnessProc.running = true;
    }

    // ── Keyboard backlight (Dell laptop) ──
    property int kbdBacklightValue: 0
    property int kbdBacklightMax: 2

    Process {
        id: kbdBacklightProc
        command: ["cat", "/sys/class/leds/dell::kbd_backlight/brightness"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let v = parseInt(data.trim());
                if (!isNaN(v)) brightness.kbdBacklightValue = v;
            }
        }
    }

    Process {
        id: kbdBacklightMaxProc
        command: ["cat", "/sys/class/leds/dell::kbd_backlight/max_brightness"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                let v = parseInt(data.trim());
                if (!isNaN(v) && v > 0) brightness.kbdBacklightMax = v;
            }
        }
    }

    Process { id: setKbdBacklightProc; running: false }

    function setKbdBacklight(pct) {
        // pct is 0-100; map to raw kbdBacklightMax levels
        let raw = Math.round((pct / 100.0) * Math.max(1, kbdBacklightMax));
        raw = Math.max(0, Math.min(kbdBacklightMax, raw));
        setKbdBacklightProc.command = ["sh", "-c", "echo " + raw + " > /sys/class/leds/dell::kbd_backlight/brightness"];
        setKbdBacklightProc.running = true;
    }

    // ── Dark mode (gsettings) ──
    property bool darkModeActive: false

    Process {
        id: darkModeTimer
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                brightness.darkModeActive = data.trim().includes("prefer-dark");
            }
        }
    }

    Process { id: setDarkModeProc; running: false }

    function setDarkMode(active) {
        setDarkModeProc.command = ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", active ? "prefer-dark" : "default"];
        setDarkModeProc.running = true;
    }

    // ── Night light (placeholder — Hyprland, no backend yet) ──
    property bool nightLightActive: false
    function setNightLight(active) {
        console.log("Night Light: placeholder only (Hyprland backend not implemented)");
        // TODO: implement with gammastep or equivalent
    }

    // ── Auto-brightness (placeholder — Hyprland, no backend yet) ──
    property bool autoBrightnessActive: false
    function setAutoBrightness(active) {
        console.log("Auto Brightness: placeholder only (Hyprland backend not implemented)");
        // TODO: implement with ambient-light-sensor or equivalent
    }

    // ── Polling ──
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            kbdBacklightProc.running = true;
            darkModeTimer.running = true;
        }
    }

    // Also probe kbd backlight max on startup
    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: kbdBacklightMaxProc.running = true
    }
}
