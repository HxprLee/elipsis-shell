import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

// Background strip at the bottom of every screen. Owns the always-reserved
// 24 px exclusive zone, the dim layer, and the edge-swipe input area that
// captures the bottom-of-screen drag gesture. The dock visuals live in
// BottomBar.qml as a Top-layer PanelWindow; this surface handles input only.
PanelWindow {
    id: root
    color: "transparent"

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: 24

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 24
    aboveWindows: true

    // Reference to the sibling BottomBar popup. Used to forward swipe state
    // changes so the dock animates in response to edge swipes.
    property var dockControl: null

    // Swipe gesture state — lives here because BackgroundBar's surface is
    // what actually reaches the screen bottom edge.
    property real swipeStartTime: 0
    property real touchStartX: 0
    property real touchStartY: 0
    property bool isSwiping: false
    property bool switcherTriggered: false

    // Full-width transparent hitbox covering the entire 24 px reservation
    // strip. MouseArea below binds to this so input on the whole strip
    // (not just the visible dim layer) goes to the swipe handler.
    Rectangle {
        id: touchHitBox
        anchors.fill: parent
        color: "transparent"
    }

    // Input mask: only the touchHitBox rectangle grabs input. Everything
    // else in this window passes through (clicks above the 24 px strip go
    // straight to whatever app is below).
    mask: Region { item: touchHitBox }

    Rectangle {
        id: bottomBarBg
        anchors.fill: parent
        // Baseline band is faintly visible so the user can always see the
        // reserved strip at the bottom of the screen. The full dim fades
        // in for the single-tiled-window case.
        color: shellRoot.hasSingleTiledWindow && shellRoot.barState === "handle"
            ? Qt.rgba(0, 0, 0, 0.6)
            : Qt.rgba(0, 0, 0, 0)
        Behavior on color {
            ColorAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
    }

    Binding {
        target: bottomBarBg
        property: "color"
        when: !shellRoot.blurEnabled
        value: Qt.rgba(0, 0, 0, 0.5)
    }

    // Timer: hold a swipe-up for 80 ms to open the task switcher.
    Timer {
        id: switcherHoldTimer
        interval: 80
        onTriggered: {
            if (isSwiping && shellRoot.barState === "handle") {
                shellRoot.closeOtherOverlays("switcher");
                shellRoot.switcherOpen = true;
                switcherTriggered = true;
            }
        }
    }

    MouseArea {
        id: touchArea
        anchors.fill: touchHitBox
        acceptedButtons: Qt.LeftButton

        onPressed: mouse => {
            touchStartX = mouse.x;
            touchStartY = mouse.y;
            swipeStartTime = Date.now();
            isSwiping = false;
        }

        onPositionChanged: mouse => {
            let dx = mouse.x - touchStartX;
            let dy = mouse.y - touchStartY;

            if (!isSwiping && (Math.abs(dx) > 15 || Math.abs(dy) > 15)) {
                isSwiping = true;
            }

            if (isSwiping && dockControl) {
                // Forward the drag to the dock popup so it can animate
                // along with the finger at half-travel.
                dockControl.swipeDelta = Qt.point(dx, dy);

                // Hold swipe-up for 80 ms → open task switcher.
                if (dy < -100 && !switcherHoldTimer.running && !switcherTriggered) {
                    switcherHoldTimer.start();
                }
            }
        }

        onReleased: mouse => {
            switcherHoldTimer.stop();

            if (!isSwiping) {
                isSwiping = false;
                return;
            }

            let dx = mouse.x - touchStartX;
            let dy = mouse.y - touchStartY;
            let duration = Date.now() - swipeStartTime;
            let velocity = Math.abs(dy) / Math.max(1, duration);

            if (dockControl) {
                // Reset dock's translate
                dockControl.swipeDelta = Qt.point(0, 0);

                // Horizontal swipe → workspace switch (only in handle state)
                if (Math.abs(dx) > 100 && shellRoot.barState === "handle") {
                    Hyprland.dispatch("hl.dsp.focus({ workspace = '" + (dx < 0 ? "+1" : "-1") + "' })");
                }

                // Swipe up → open overlay or dock (skip if hold-triggered switcher)
                if (dy < -30 && !switcherTriggered) {
                    if (velocity > 1.5) {
                        Hyprland.dispatch("hl.dsp.window.close()");
                        dockControl.setBarState("handle", true);
                    } else {
                        dockControl.setBarState("overlay", true);
                    }
                }

                // Swipe down → collapse to handle
                if (dy > 40 && shellRoot.barState !== "handle") {
                    dockControl.setBarState("handle", true);
                }
            }

            isSwiping = false;
            switcherTriggered = false;
        }
    }
}