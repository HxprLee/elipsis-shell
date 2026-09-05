import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import ".."

// Unified context menu component. Renders a menu on a per-screen overlay
// PanelWindow at the WlrLayershell.Overlay layer, positions it at the cursor
// (or provided coordinates) with screen-edge awareness.
//
// Two usage modes:
//
// 1. Factory mode (dynamic, self-destroying) — via ShellRoot helpers:
//      shellRoot.openContextMenuAtCursor(screen, model)
//      shellRoot.closeContextMenu(screen)
//
// 2. Inline mode (persistent instance, Menu-style API):
//      ContextMenu {
//          id: myMenu
//          model: [ { text: "Item", icon: "", action: () => {} } ]
//      }
//      myMenu.popup(anchorItem, x, y)   // opens at cursor
//      onClosed: ...                    // emitted every time it hides
//
// where model is an array of { text, icon, action, isDestructive } objects;
// an entry whose text is "---" renders as a separator.
PanelWindow {
    id: root
    visible: false
    color: "transparent"

    // Only factory-created menus destroy themselves on close; inline
    // instances must survive repeated open/close cycles.
    property bool autoDestroy: false

    signal closed()

    property var targetScreen: null
    property var model: []
    property real menuX: 0
    property real menuY: 0

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrLayershell.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    screen: targetScreen

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    aboveWindows: true

    // ── Backdrop for outside-click dismissal ──
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            root.close();
        }
    }

    // ── Menu Container ──
    Item {
        id: menuContainer
        width: menuWidth
        height: menuHeight

        // Calculate position with edge awareness
        x: computeX()
        y: computeY()

        // Menu dimensions
        property real menuWidth: 220
        property real menuHeight: menuColumn.height + 16

        // Edge-aware positioning - using functions to avoid binding loops
        function computeX() {
            if (!targetScreen) return menuX;

            const margin = 8;
            const screenWidth = targetScreen.width;
            const screenX = targetScreen.x;

            let x = menuX;

            // If too close to right edge, show menu to the left of cursor
            if (menuX + menuWidth > screenX + screenWidth - margin) {
                x = menuX - menuWidth - 16;
            }

            // Clamp to screen bounds
            if (x < screenX + margin) {
                x = screenX + margin;
            } else if (x + menuWidth > screenX + screenWidth - margin) {
                x = screenX + screenWidth - menuWidth - margin;
            }

            return x;
        }

        function computeY() {
            if (!targetScreen) return menuY;

            const margin = 8;
            const screenHeight = targetScreen.height;
            const screenY = targetScreen.y;

            let y = menuY;

            // If too close to bottom edge, show menu above cursor
            if (menuY + menuHeight > screenY + screenHeight - margin) {
                y = menuY - menuHeight - 16;
            }

            // Clamp to screen bounds
            if (y < screenY + margin) {
                y = screenY + margin;
            } else if (y + menuHeight > screenY + screenHeight - margin) {
                y = screenY + screenHeight - menuHeight - margin;
            }

            return y;
        }

        // Menu background with material surface
        Item {
            id: menuBg
            width: menuWidth
            height: menuColumn.height + 16

            MaterialSurface {
                id: bgSurface
                anchors.fill: parent
                radius: 12
                isActive: false
            }

            Column {
                id: menuColumn
                anchors.centerIn: parent
                spacing: 4

                Repeater {
                    model: root.model

                    delegate: Item {
                        id: menuItem
                        width: menuWidth - 16
                        height: itemRow.height + 12

                        readonly property bool isSeparator: modelData.text === "---"

                        // Separator
                        Rectangle {
                            anchors.fill: parent
                            visible: isSeparator
                            color: "transparent"

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                height: 1
                                color: Qt.rgba(255, 255, 255, 0.15)
                            }
                        }

                        // Menu item row
                        Row {
                            id: itemRow
                            anchors.centerIn: parent
                            spacing: 12
                            visible: !isSeparator

                            // Icon
                            Item {
                                width: 20
                                height: 20
                                visible: modelData.icon && modelData.icon !== ""

                                Image {
                                    id: menuIconImg
                                    anchors.centerIn: parent
                                    width: 18
                                    height: 18
                                    sourceSize: Qt.size(18, 18)
                                    source: modelData.icon
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon || ""
                                    font.family: "SF Symbols, Segoe MDL2 Assets, Arial"
                                    font.pixelSize: 16
                                    color: modelData.isDestructive
                                        ? Qt.rgba(1, 0.3, 0.3, 1)
                                        : bgSurface.fgColor
                                    visible: parent.visible && menuIconImg.status !== Image.Ready
                                }
                            }

                            // Text
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.text || ""
                                color: modelData.isDestructive
                                    ? Qt.rgba(1, 0.3, 0.3, 1)
                                    : bgSurface.fgColor
                                font.pixelSize: 14
                                font.weight: Font.Normal
                            }
                        }

                        // Click handling
                        MouseArea {
                            anchors.fill: parent
                            enabled: !isSeparator && modelData.action !== undefined
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true

                            onEntered: bgHighlight.visible = true
                            onExited: bgHighlight.visible = false
                            onClicked: {
                                if (modelData.action && typeof modelData.action === "function") {
                                    modelData.action();
                                }
                                root.close();
                            }
                        }

                        // Hover highlight
                        Rectangle {
                            id: bgHighlight
                            anchors.fill: parent
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            radius: 6
                            color: modelData.isDestructive
                                ? Qt.rgba(1, 0.3, 0.3, 0.15)
                                : Qt.rgba(255, 255, 255, 0.1)
                            visible: false
                        }
                    }
                }
            }
        }

        // Scale animation on open
        NumberAnimation {
            id: openAnim
            target: menuBg
            property: "scale"
            from: 0.9
            to: 1.0
            duration: 150
            easing.type: Easing.OutBack
        }

        OpacityAnimator {
            id: fadeAnim
            target: menuBg
            from: 0
            to: 1
            duration: 150
        }
    }

    // Menu-style API: open anchored near the given item. The click that
    // triggers this just happened, so the compositor's cursor position is
    // the most reliable anchor across windows — local item mapping has
    // proven unreliable for cross-window placement.
    function popup(anchorItem, px, py) {
        let scr = targetScreen;
        if (anchorItem) {
            const win = anchorItem.Window ? anchorItem.Window.window : null;
            if (win && win.screen) scr = win.screen;
        }

        let x = px || 0;
        let y = py || 0;
        const cursor = Hyprland.cursorPosition;
        if (cursor) {
            x = cursor.x + 4;
            y = cursor.y + 4;
        } else if (scr) {
            x = scr.x + scr.width / 2;
            y = scr.y + scr.height / 2;
        }

        open(scr, model, x, y);
    }

    function open(screen, mdl, x, y) {
        targetScreen = screen;
        model = mdl || [];
        menuX = x || 0;
        menuY = y || 0;

        visible = true;
        openAnim.from = 0.9;
        openAnim.start();
        fadeAnim.start();
    }

    function close() {
        const wasVisible = visible;
        visible = false;
        if (autoDestroy)
            closeTimer.restart();
        if (wasVisible)
            closed();
    }

    Timer {
        id: closeTimer
        interval: 200
        onTriggered: {
            root.destroy();
        }
    }
}
