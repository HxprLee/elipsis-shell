import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import "reusables"

PanelWindow {
    id: root
    visible: shellRoot.appDrawerOpen
    color: "transparent"

    property string selectedCategory: "All"

    property var allCategories: {
        const mainCategories = [
            "AudioVideo", "Audio", "Video", "Development", "Education", 
            "Game", "Graphics", "Network", "Office", "Science", 
            "Settings", "System", "Utility"
        ];
        let apps = DesktopEntries.applications.values;
        let cats = new Set();
        cats.add("All");
        for (let app of apps) {
            if (app.categories) {
                for (let cat of app.categories) {
                    if (mainCategories.includes(cat)) {
                        cats.add(cat);
                    }
                }
            }
        }
        return Array.from(cats).sort();
    }

    function switchCategory(delta) {
        let cats = allCategories;
        let idx = cats.indexOf(selectedCategory);
        if (idx === -1) idx = 0;
        
        idx += delta;
        if (idx < 0) idx = cats.length - 1;
        if (idx >= cats.length) idx = 0;
        
        selectedCategory = cats[idx];
        appGrid.contentY = 0;
    }

    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrLayershell.OnDemand : WlrLayershell.None

    onVisibleChanged: {
        if (visible) {
            focusTimer.restart();
        } else {
            // Closing the drawer should also dismiss the shared menu on
            // our screen so a stale overlay doesn't linger.
            shellRoot.closeContextMenu(root.screen);
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: searchField.forceActiveFocus();
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true

    // --- Background with Sharp Premium Blur ---
    Item {
        id: bgContainer
        anchors.fill: parent
        opacity: root.visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        Image {
            id: bgBlur
            anchors.fill: parent
            source: shellRoot.blurredWallpaperPath
            cache: false
            fillMode: Image.PreserveAspectCrop
            
            Connections {
                target: shellRoot
                function onBlurVersionChanged() {
                    let s = bgBlur.source
                    bgBlur.source = ""
                    bgBlur.source = s
                }
            }
            visible: shellRoot.usePrecomputedBlur && shellRoot.staticBlurEnabled
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.02, 0.02, 0.05, 0.6)
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: shellRoot.appDrawerOpen = false
        }
    }

    function buildAppMenuModel(app) {
        let menuModel = []
        let isPinned = shellRoot.pinnedApps.includes(app.id.toLowerCase())

        // Pin/Unpin item
        menuModel.push({
            text: isPinned ? "Unpin from Dock" : "Add to Dock",
            icon: shellRoot.icon(isPinned ? "window-close-symbolic" : "view-app-grid-symbolic"), // Placeholders
            action: () => {
                shellRoot.togglePin(app.id)
                shellRoot.closeContextMenu(root.screen)
            }
        })

        return menuModel;
    }

    // --- Content Container ---
    Item {
        id: content
        anchors.fill: parent
        opacity: root.visible ? 1.0 : 0.0
        scale: root.visible ? 1.0 : 0.95
        
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

        // Main Layout Wrapper
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 80
            anchors.bottomMargin: 120
            anchors.leftMargin: 100
            anchors.rightMargin: 100
            spacing: 20

            // Search Bar
            MaterialSurface {
                id: searchBar
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(parent.width * 0.6, 600)
                height: 60
                radius: 30

                // Focus indicator border
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 2
                    border.color: searchField.activeFocus ? Qt.rgba(1, 1, 1, 0.3) : "transparent"
                    Behavior on border.color { ColorAnimation { duration: 200 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 12

                    Text {
                        text: "🔍"
                        font.pixelSize: 20
                        opacity: 0.6
                        color: "white"
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: "Search apps..."
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
                        color: "white"
                        font.pixelSize: 18
                        background: null
                        focus: root.visible
                        
                        Keys.onEscapePressed: {
                            shellRoot.appDrawerOpen = false
                            searchField.text = ""
                        }

                        onTextChanged: {
                            appGrid.contentY = 0
                        }
                    }

                    Button {
                        visible: searchField.text !== ""
                        text: "✕"
                        flat: true
                        palette.buttonText: "white"
                        onClicked: searchField.text = ""
                    }
                }
            }

            // Category Filter Pills
            Flickable {
                id: catFlick
                Layout.fillWidth: true
                height: 40
                contentWidth: catRow.width
                clip: true
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: catRow
                    spacing: 16
                    x: Math.max(0, (parent.width - width) / 2)
                    leftPadding: 20
                    rightPadding: 20

                    Repeater {
                        model: root.allCategories
                        delegate: Button {
                            id: catBtn
                            text: modelData
                            flat: true
                            
                            contentItem: Text {
                                text: catBtn.text
                                color: "white"
                                font.pixelSize: 14
                                font.weight: root.selectedCategory === modelData ? Font.Bold : Font.Normal
                                opacity: root.selectedCategory === modelData ? 1.0 : 0.6
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                implicitWidth: 80
                                implicitHeight: 32
                                radius: 16
                                color: root.selectedCategory === modelData ? Qt.rgba(1, 1, 1, 0.2) : (catBtn.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent")
                                border.color: root.selectedCategory === modelData ? Qt.rgba(1, 1, 1, 0.3) : "transparent"
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            onClicked: {
                                root.selectedCategory = modelData
                                appGrid.contentY = 0
                            }
                        }
                    }
                }
            }

            // --- App Grid ---
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: appGrid
                    anchors.fill: parent
                    
                    property int columns: Math.max(1, Math.floor(width / 140))
                    cellWidth: width / columns
                    cellHeight: 160
                    clip: true
                    
                    ScrollBar.vertical: ScrollBar {
                        active: true
                    }
                    
                    // ... (filtering logic)
                    model: {
                        let apps = DesktopEntries.applications.values.filter(a => !a.noDisplay);
                        
                        // Filter by category
                        if (root.selectedCategory !== "All") {
                            apps = apps.filter(a => a.categories && a.categories.includes(root.selectedCategory));
                        }

                        // Filter by search
                        let filter = searchField.text.toLowerCase();
                        if (filter !== "") {
                            apps = apps.filter(a => a.name.toLowerCase().includes(filter));
                        }
                        
                        return apps.sort((a, b) => a.name.localeCompare(b.name));
                    }

                    add: Transition {
                        NumberAnimation { property: "opacity"; from: 0; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "scale"; from: 0.5; to: 1.0; duration: 500; easing.type: Easing.OutBack }
                    }

                    delegate: Item {
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight

                        property var entry: modelData
                        
                        Column {
                            anchors.centerIn: parent
                            spacing: 12
                            
                            Item {
                                width: 80; height: 80
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                Rectangle {
                                    id: iconBg
                                    anchors.fill: parent
                                    radius: 20
                                    color: appMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }

                                Image {
                                    id: appIcon
                                    anchors.centerIn: parent
                                    width: 64; height: 64
                                    sourceSize: Qt.size(128, 128)
                                    fillMode: Image.PreserveAspectFit
                                    source: {
                                        if (!entry.icon) return "";
                                        if (entry.icon.startsWith("/")) return "file://" + entry.icon;
                                        return "image://icon/" + entry.icon;
                                    }
                                    
                                    scale: appMouse.pressed ? 0.9 : (appMouse.containsMouse ? 1.1 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                                    visible: status === Image.Ready
                                }

                                // Fallback icons if image fails
                                Text {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    font.pixelSize: 32
                                    color: "white"
                                    text: {
                                        let n = entry.name.toLowerCase();
                                        if (n.includes("browser")) return "🌐";
                                        if (n.includes("file")) return "📂";
                                        if (n.includes("terminal")) return "📟";
                                        if (n.includes("settings")) return "⚙️";
                                        return entry.name.charAt(0).toUpperCase();
                                    }
                                }
                                
                                // Visual indicator if already running
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: -6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 5; height: 5; radius: 2.5
                                    color: "white"
                                    opacity: 0.8
                                    visible: shellRoot.runningAppIds.includes(entry.id)
                                }
                            }

                            Text {
                                text: entry.name
                                color: "white"
                                width: appGrid.cellWidth - 10
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                opacity: appMouse.containsMouse ? 1.0 : 0.8
                            }
                        }

                        MouseArea {
                            id: appMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            pressAndHoldInterval: 300
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    // Ask the compositor for the cursor
                                    // position rather than trusting local
                                    // MouseArea mapping, which has been
                                    // unreliable for menu placement.
                                    shellRoot.openContextMenuAtCursor(root.screen, buildAppMenuModel(entry))
                                } else {
                                    entry.execute()
                                    shellRoot.appDrawerOpen = false
                                    searchField.text = ""
                                }
                            }
                            onPressAndHold: {
                                shellRoot.openContextMenuAtCursor(root.screen, buildAppMenuModel(entry))
                            }
                        }
                    }

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: LinearGradient {
                            width: appGrid.width
                            height: appGrid.height
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.1; color: "white" }
                                GradientStop { position: 0.9; color: "white" }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }
                }

                // Swipe Detection
                MouseArea {
                    anchors.fill: parent
                    z: 10 // Above the grid
                    propagateComposedEvents: true
                    
                    property real startX: 0
                    property real startY: 0
                    property bool draggingHorizontally: false

                    onPressed: (mouse) => {
                        startX = mouse.x
                        startY = mouse.y
                        draggingHorizontally = false
                        mouse.accepted = false // Let it pass to GridView/delegate
                    }

                    onPositionChanged: (mouse) => {
                        if (!draggingHorizontally) {
                            let dx = mouse.x - startX
                            let dy = mouse.y - startY
                            if (Math.abs(dx) > 30 && Math.abs(dx) > Math.abs(dy)) {
                                draggingHorizontally = true
                            }
                        }
                        
                        if (draggingHorizontally) {
                            mouse.accepted = true // Prevent scrolling/clicks while swiping
                        } else {
                            mouse.accepted = false
                        }
                    }

                    onReleased: (mouse) => {
                        if (draggingHorizontally) {
                            let dx = mouse.x - startX
                            if (dx > 80) root.switchCategory(-1)
                            else if (dx < -80) root.switchCategory(1)
                            draggingHorizontally = false
                            mouse.accepted = true
                        } else {
                            mouse.accepted = false
                        }
                    }
                }
            }
        }
    }

    // --- Shortcuts ---
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: {
            shellRoot.appDrawerOpen = false
            searchField.text = ""
        }
    }
}
