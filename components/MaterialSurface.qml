import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Item {
    id: root

    // Configurable properties
    property real radius: 8
    property bool isActive: false // For toggles when they are "on"
    property bool isToggleCircle: false // For inner toggle circles

    // Internal material property driven by the global shellRoot
    property string material: shellRoot.materialTheme || "Acrylic"
    property color accentColor: shellRoot.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)

    // Exposed foreground color for icons/text
    property color fgColor: {
        if (root.isActive && root.material === "Frosted Glass")
            return "black";
        if (root.isActive)
            return "white";
        return "white";
    }

    // Exposed color for icons
    property color iconColor: {
        if (root.isActive && root.material === "Frosted Glass")
            return accentColor;
        return fgColor;
    }

    // "Solid"
    property color solidBg: Qt.rgba(0.05, 0.05, 0.1, 1.0)

    // "Acrylic"
    property color acrylicBg: Qt.rgba(1.0, 1.0, 1.0, 0.25)
    property color acrylicBorder: Qt.rgba(1.0, 1.0, 1.0, 0.2)

    // "Frosted Glass"
    property color frostedBg: Qt.rgba(1.0, 1.0, 1.0, 0.1)

    // Main background layer
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: root.radius
        color: {
            if (root.isActive && root.material === "Frosted Glass")
                return Qt.rgba(1.0, 1.0, 1.0, 0.8);
            if (root.isActive)
                return root.accentColor;

            if (root.isToggleCircle)
                return Qt.rgba(1.0, 1.0, 1.0, 0.15);

            if (root.material === "Solid")
                return root.solidBg;
            if (root.material === "Acrylic")
                return root.acrylicBg;
            if (root.material === "Frosted Glass")
                return root.frostedBg;

            return "transparent";
        }
        Behavior on color {
            ColorAnimation {
                duration: 200
            }
        }
    }

    // Border for "Acrylic"
    Rectangle {
        id: acrylicBorderRect
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.acrylicBorder
        visible: root.material === "Acrylic" && !root.isActive && !root.isToggleCircle
    }

    // Border for "Frosted Glass"
    Rectangle {
        id: frostedBorderMask
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: "black"
        visible: false
    }

    LinearGradient {
        anchors.fill: frostedBorderMask
        source: frostedBorderMask
        visible: root.material === "Frosted Glass" && !root.isActive && !root.isToggleCircle
        start: Qt.point(width / 3, 0)
        end: Qt.point(width - width / 3, height)
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(1.0, 1.0, 1.0, 0.4)
            }
            GradientStop {
                position: 0.25
                color: Qt.rgba(1.0, 1.0, 1.0, 0.0)
            }
            GradientStop {
                position: 0.75
                color: Qt.rgba(1.0, 1.0, 1.0, 0.0)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(1.0, 1.0, 1.0, 0.2)
            }
        }
    }
}
