pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Caffeine singleton — pauses hypridle via pkill -STOP/-CONT.
// Owns caffeineActive flag. If pkill fails (hypridle not running),
// reverts the optimistic state update.

QtObject {
    id: caffeine

    property bool caffeineActive: false

    function setCaffeine(active) {
        caffeineActive = active;
        if (active) {
            caffeineProc.command = ["pkill", "-STOP", "hypridle"];
        } else {
            caffeineProc.command = ["pkill", "-CONT", "hypridle"];
        }
        caffeineProc.running = true;
    }

    Process {
        id: caffeineProc
        running: false
        onExited: (code) => {
            // If pkill failed (e.g., hypridle not running), revert the optimistic update.
            if (code !== 0) {
                caffeine.caffeineActive = !caffeine.caffeineActive;
                console.warn("[Caffeine] pkill exited with code", code, "- reverted state");
            }
        }
    }
}
