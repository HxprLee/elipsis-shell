pragma Singleton
import QtQuick

// Icons singleton — direct lookup for breeze-dark theme icons.
// Replaces shellRoot.icon(name). Consumers should call Icons.icon(name).
//
// The lookup table is held on the `_table` property so it is created
// once at singleton-init time. Before this, icon() rebuilt a 60+ entry
// object literal on every call — fine when called once per repaint, but
// expensive on the QuickSettings grid where widgetBg repaints happen
// per cell, per page change, and on every theme/material switch.
QtObject {
    readonly property var _table: ({
        "network-wireless-signal-excellent-symbolic": "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-excellent-symbolic.svg",
        "network-wireless-signal-good-symbolic":      "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-good-symbolic.svg",
        "network-wireless-signal-ok-symbolic":        "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-ok-symbolic.svg",
        "network-wireless-signal-weak-symbolic":      "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-weak-symbolic.svg",
        "network-wireless-signal-none-symbolic":      "file:///usr/share/icons/breeze-dark/status/24/network-wireless-signal-none-symbolic.svg",
        "network-wireless-offline-symbolic":          "file:///usr/share/icons/breeze-dark/actions/24/network-disconnect-symbolic.svg",
        "network-disconnect-symbolic":                "file:///usr/share/icons/breeze-dark/actions/24/network-disconnect-symbolic.svg",
        "network-wireless-symbolic":                  "file:///usr/share/icons/breeze-dark/devices/24/network-wireless-symbolic.svg",
        "network-wired-symbolic":                     "file:///usr/share/icons/breeze-dark/devices/24/network-wired-symbolic.svg",
        "network-wired-offline-symbolic":             "file:///usr/share/icons/breeze-dark/actions/24/network-disconnect-symbolic.svg",
        "bluetooth-active-symbolic":           "file:///usr/share/icons/breeze-dark/preferences/24/preferences-system-bluetooth-activated-symbolic.svg",
        "bluetooth-disabled-symbolic":         "file:///usr/share/icons/breeze-dark/preferences/24/preferences-system-bluetooth-inactive-symbolic.svg",
        "preferences-system-symbolic":         "file:///usr/share/icons/breeze-dark/actions/24/preferences-system-symbolic.svg",
        "system-lock-screen-symbolic":         "file:///usr/share/icons/breeze-dark/actions/24/system-lock-screen-symbolic.svg",
        "system-shutdown-symbolic":            "file:///usr/share/icons/breeze-dark/actions/24/system-shutdown-symbolic.svg",
        "display-brightness-symbolic":         "file:///usr/share/icons/breeze-dark/actions/24/high-brightness-symbolic.svg",
        "audio-volume-high-symbolic":          "file:///usr/share/icons/breeze-dark/status/24/audio-volume-high-symbolic.svg",
        "audio-volume-medium-symbolic":        "file:///usr/share/icons/breeze-dark/status/24/audio-volume-medium-symbolic.svg",
        "audio-volume-low-symbolic":           "file:///usr/share/icons/breeze-dark/status/24/audio-volume-low-symbolic.svg",
        "audio-volume-muted-symbolic":         "file:///usr/share/icons/breeze-dark/status/24/audio-volume-muted-symbolic.svg",
        "battery-missing-symbolic":            "file:///usr/share/icons/breeze-dark/status/24/battery-missing-symbolic.svg",
        "window-close-symbolic":               "file:///usr/share/icons/breeze-dark/actions/24/window-close-symbolic.svg",
        "view-app-grid-symbolic":              "file:///usr/share/icons/breeze-dark/actions/24/view-grid-symbolic.svg",
        "go-up-symbolic":                      "file:///usr/share/icons/breeze-dark/actions/24/go-up-symbolic.svg",
        "edit-clear-all-symbolic":             "file:///usr/share/icons/breeze-dark/actions/24/edit-clear-all-symbolic.svg",
        "go-next-symbolic":                    "file:///usr/share/icons/breeze-dark/actions/24/go-next-symbolic.svg",
        "view-refresh-symbolic":               "file:///usr/share/icons/breeze-dark/actions/24/view-refresh-symbolic.svg",
        "object-select-symbolic":              "file:///usr/share/icons/breeze-dark/actions/16/object-select-symbolic.svg",
        "notifications-disabled-symbolic":     "file:///usr/share/icons/breeze-dark/actions/24/notifications-disabled-symbolic.svg",
        "emblem-ok-symbolic":                  "file:///usr/share/icons/breeze-dark/emblems/16/emblem-ok-symbolic.svg",
        "system-reboot-symbolic":              "file:///usr/share/icons/breeze-dark/actions/24/system-reboot-symbolic.svg",
        "system-suspend-symbolic":             "file:///usr/share/icons/breeze-dark/actions/24/system-suspend-symbolic.svg",
        "power-profile-power-saver":           "file:///usr/share/icons/breeze-dark/status/22/battery-profile-powersave-symbolic.svg",
        "power-profile-balanced":              "file:///usr/share/icons/breeze-dark/status/22/battery-profile-balanced-symbolic.svg",
        "power-profile-performance":           "file:///usr/share/icons/breeze-dark/status/22/battery-profile-performance-symbolic.svg",
        "system-suspend-inhibited-symbolic":   "file:///usr/share/icons/breeze-dark/status/24/system-suspend-inhibited.svg",
        "multimedia-audio-player-symbolic":    "file:///usr/share/icons/breeze-dark/apps/48/multimedia-audio-player.svg",
        "spotify":                             "file:///usr/share/icons/breeze-dark/apps/48/spotify-client.svg",
        "vlc":                                 "file:///usr/share/icons/breeze-dark/apps/48/vlc.svg",
        "elisa":                               "file:///usr/share/icons/breeze-dark/apps/48/elisa.svg",
        "mpv":                                 "file:///usr/share/icons/breeze-dark/apps/48/mpv.svg",
        "firefox":                             "file:///usr/share/icons/breeze-dark/apps/48/firefox.svg",
        "chromium":                            "file:///usr/share/icons/breeze-dark/apps/48/chromium-browser.svg",
        "dark-mode-symbolic":           "file:///usr/share/icons/Qogir/symbolic/actions/dark-mode-symbolic.svg",
        "night-light-symbolic":          "file:///usr/share/icons/Adwaita/symbolic/status/night-light-symbolic.svg",
        "auto-brightness-symbolic":     "file:///usr/share/icons/Qogir/symbolic/actions/layout-auto-symbolic.svg",
        "keyboard-brightness-symbolic": "file:///usr/share/icons/breeze-dark/status/24/input-keyboard-brightness.svg",
        "input-keyboard-symbolic":     "file:///usr/share/icons/breeze-dark/devices/24/input-keyboard-symbolic.svg",
        "document-edit-symbolic":     "file:///usr/share/icons/breeze-dark/actions/24/document-edit-symbolic.svg",
        "checkmark-symbolic":         "file:///usr/share/icons/breeze-dark/actions/24/checkmark-symbolic.svg",
        "list-add-symbolic":          "file:///usr/share/icons/breeze-dark/actions/24/list-add-symbolic.svg",
        "list-remove-symbolic":       "file:///usr/share/icons/breeze-dark/actions/24/list-remove-symbolic.svg",
        "system-search-symbolic":     "file:///usr/share/icons/breeze-dark/actions/24/system-search-symbolic.svg",
        "web-browser-symbolic":       "file:///usr/share/icons/breeze-dark/apps/48/internet-web-browser.svg",
        "folder-symbolic":            "file:///usr/share/icons/breeze-dark/actions/24/document-open-folder-symbolic.svg",
        "terminal-symbolic":          "file:///usr/share/icons/breeze-dark/apps/48/utilities-terminal.svg",
    })

    readonly property string _batteryPrefix: "file:///usr/share/icons/breeze-dark/status/24/"
    readonly property string _mediaPrefix:   "file:///usr/share/icons/breeze-dark/actions/24/"
    readonly property string _multimediaPrefix: "file:///usr/share/icons/breeze-dark/apps/48/"

    function icon(name) {
        if (_table[name] !== undefined) return _table[name];

        if (name.startsWith("battery-")) return _batteryPrefix + name + ".svg";
        if (name.startsWith("media-"))   return _mediaPrefix + name + ".svg";
        if (name.startsWith("multimedia-")) {
            return _multimediaPrefix + name.replace("-symbolic", "") + ".svg";
        }
        return "";
    }
}
