pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// PipewireAvailability — parses pw-dump JSON to expose per-port
// availability. Used by VolumeSlider to hide unplugged ports.
Item {
    id: pwAvail

    // Map<id, true> of node ids whose port is currently available=no.
    // Empty until the first pw-dump returns.
    property var unpluggedIds: ({})
    property bool ready: false

    function isUnplugged(id) { return id !== undefined && unpluggedIds[String(id)] === true; }

    Timer {
        // Aligned with Wallpapers' 2s wallpaper poll so the two long-running
        // pollers (pw-dump + awww query) breathe in the same phase.
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pwDumpProc.running = true
    }

    Process {
        id: pwDumpProc
        command: ["pw-dump"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let map = ({});
                try {
                    const arr = JSON.parse(text);
                    // First pass: index devices by id and their EnumRoute availability
                    let deviceRoutes = ({}); // deviceId -> { routeIdx: "yes"|"no"|"unknown" }
                    for (const obj of arr) {
                        if (obj.type !== "PipeWire:Interface:Device") continue;
                        const did = String(obj.id);
                        const enumRoute = obj.info && obj.info.params && obj.info.params.EnumRoute;
                        if (!enumRoute) continue;
                        const routeMap = ({});
                        for (const r of enumRoute) {
                            routeMap[String(r.index)] = r.available;
                        }
                        deviceRoutes[did] = routeMap;
                    }
                    // Second pass: walk nodes, mark unplugged
                    for (const obj of arr) {
                        if (obj.type !== "PipeWire:Interface:Node") continue;
                        const props = obj.info && obj.info.props;
                        if (!props) continue;
                        const did = props["device.id"];
                        const idx = props["card.profile.device"];
                        if (did === undefined || idx === undefined) continue;
                        const routeMap = deviceRoutes[String(did)];
                        if (!routeMap) continue;
                        if (routeMap[String(idx)] === "no") map[String(obj.id)] = true;
                    }
                } catch (e) {
                    // Leave previous unpluggedIds in place on parse failure.
                    return;
                }
                pwAvail.unpluggedIds = map;
                pwAvail.ready = true;
            }
        }
    }
}