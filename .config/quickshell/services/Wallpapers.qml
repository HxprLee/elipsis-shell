pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Wallpapers singleton — wallpaper path query + blur pipeline +
// appearance properties (materialTheme, accentColor, blurEnabled, ...).
// ConfigStore reads/writes these via Wallpapers.materialTheme, etc.
Item {
    id: wallpapers

    property string materialTheme: "Acrylic"
    property var accentColor: null

    property string wallpaperPath: ""
    property int blurVersion: 0
    property string blurredWallpaperPath: "file:///tmp/elipsis_blur.png"
    property bool usePrecomputedBlur: true
    property bool staticBlurEnabled: true
    property bool blurEnabled: true

    Process {
        id: wallpaperQuery
        command: ["awww", "query"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                let match = line.match(/image: (.*)/);
                if (match) {
                    let path = match[1].trim();
                    if (wallpapers.wallpaperPath !== path) {
                        wallpapers.wallpaperPath = path;
                        if (wallpapers.usePrecomputedBlur) blurGenerator.startBlur();
                    }
                }
            }
        }
    }

    Timer {
        interval: 2000 // Poll wallpaper every 2s for snappier response
        running: true
        repeat: true
        onTriggered: if (!wallpaperQuery.running) wallpaperQuery.running = true
    }

    Process {
        id: blurGenerator
        function startBlur() {
            if (wallpapers.wallpaperPath === "") return;
            // High-speed optimization:
            // 1. Use -sample for ultra-fast downscaling (5%)
            // 2. Use -blur with small radius on tiny image
            // 3. Use -resize for smooth upscaling back to 100%
            command = ["magick", wallpapers.wallpaperPath, "-sample", "5%", "-blur", "0x2", "-resize", "2000%", "/tmp/elipsis_blur.png"];
            running = true;
        }
        onExited: (code) => {
            if (code === 0) wallpapers.blurVersion++;
        }
    }

    function setPrecomputedBlur(enabled) {
        let s = String(enabled).toLowerCase();
        let isEnabled = (s === "true" || s === "1" || s === "yes" || s === "on");
        usePrecomputedBlur = isEnabled;
        if (isEnabled && wallpaperPath !== "") blurGenerator.startBlur();
    }

    function setBlurEnabled(enabled) {
        let s = String(enabled).toLowerCase();
        let isEnabled = (s === "true" || s === "1" || s === "yes" || s === "on");
        blurEnabled = isEnabled;
    }

    function setMaterial(material) {
        if (typeof material !== "string") return;
        if (["Solid", "Acrylic", "Frosted Glass"].includes(material)) {
            materialTheme = material;
        } else {
            console.warn("Unknown material:", material);
        }
    }

    // Auto-save appearance settings on change.
    Connections {
        target: wallpapers
        function onMaterialThemeChanged() { ConfigStore.saveAppearance(); }
        function onBlurEnabledChanged() { ConfigStore.saveAppearance(); }
        function onAccentColorChanged() { ConfigStore.saveAppearance(); }
        function onWallpaperPathChanged() { ConfigStore.saveAppearance(); }
        function onStaticBlurEnabledChanged() { ConfigStore.saveAppearance(); }
    }
}
