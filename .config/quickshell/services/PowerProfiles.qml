pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// PowerProfiles singleton — talks to net.hadess.PowerProfiles D-Bus.
// Owns the powerProfile state and the busctl get/set processes.

QtObject {
    id: powerProfiles

    property string powerProfile: "balanced"

    Process {
        id: getPowerProfileProc
        command: ["busctl", "get-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                // data looks like: s "performance"
                let parts = data.trim().split('"');
                if (parts.length >= 2) {
                    powerProfiles.powerProfile = parts[1];
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            getPowerProfileProc.running = true;
        }
    }

    Process { id: setPowerProfileProc; running: false }

    function setPowerProfile(profile) {
        powerProfile = profile; // optimistic update
        setPowerProfileProc.command = ["busctl", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile", "s", profile];
        setPowerProfileProc.running = true;
    }
}
