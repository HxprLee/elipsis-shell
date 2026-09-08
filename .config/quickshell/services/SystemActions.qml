pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// SystemActions singleton — power/lock/audio/launch commands.
// Owns the underlying Process instances and exposes them as functions.
// Consumers call SystemActions.powerOff() / launchExec() / etc.

Item {
    id: systemActions

    // ── Power / Lock (used by PowerMenu) ──
    Process {
        id: powerOffProc
        command: ["systemctl", "poweroff"]
        running: false
    }
    Process {
        id: restartProc
        command: ["systemctl", "reboot"]
        running: false
    }
    Process {
        id: suspendProc
        command: ["systemctl", "suspend"]
        running: false
    }
    Process {
        id: lockProc
        command: ["loginctl", "lock-session"]
        running: false
    }

    function powerOff() { powerOffProc.running = true; }
    function reboot() { restartProc.running = true; }
    function suspend() { suspendProc.running = true; }
    function lockScreen() { lockProc.running = true; }

    // ── Audio default device (used by VolumeSlider) ──
    Process {
        id: setDefaultProc
        running: false
    }
    function setDefaultAudio(nodeId) {
        if (nodeId !== undefined && nodeId !== null) {
            setDefaultProc.command = ["wpctl", "set-default", String(nodeId)];
            setDefaultProc.running = true;
        }
    }

    // ── Open system settings (used by SettingsToggle) ──
    Process {
        id: settingsProc
        command: ["sh", "-c", "hyprctl dispatch exec gnome-control-center || hyprctl dispatch exec systemsettings5 || hyprctl dispatch exec xfce4-settings-manager"]
        running: false
    }
    function openSettings() { settingsProc.running = true; }

    // ── Generic app launch (used by BottomBar dock) ──
    Process {
        id: launchProcess
        running: false
    }
    function launchEntry(entry) {
        if (entry && entry.execute) entry.execute();
    }
    function launchExec(cmd) {
        if (!cmd) return;
        launchProcess.command = ["sh", "-c", cmd];
        launchProcess.running = true;
    }

    // ── killApp — closes every window belonging to a desktop entry ──
    function killApp(entryId) {
        let toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            let tl = toplevels[i];
            let ipc = tl.lastIpcObject;
            if (!ipc) continue;

            let identifiers = [ipc.class, ipc.initialClass, tl.initialClass, tl.appId].filter(x => !!x);
            let match = false;
            for (let id of identifiers) {
                let entry = DesktopEntries.heuristicLookup(id);
                if (entry && entry.id === entryId) {
                    match = true;
                    break;
                }
            }

            if (match) {
                let safeAddr = ipc.address.toString().replace(/[^0-9a-fA-Fx]/g, "");
                Hyprland.dispatch("hl.dsp.window.close({ window = 'address:" + safeAddr + "' })");
            }
        }
    }
}
