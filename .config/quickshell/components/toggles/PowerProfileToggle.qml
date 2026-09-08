import QtQuick
import QtQuick.Layouts
import ".."
import "../../services"

// PowerProfileToggle.qml — Power Profiles toggle (data-only, styled by the shell).

Item {
    id: root
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Power Profile"
    property string subtitleText: {
        if (PowerProfiles.powerProfile === "power-saver") return "Power Saver";
        if (PowerProfiles.powerProfile === "performance") return "Performance";
        return "Balanced";
    }
    property string iconSource: Icons.icon("power-profile-" + PowerProfiles.powerProfile)
    property bool isActive: PowerProfiles.powerProfile !== "balanced"
    property color activeColor: Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)

    signal toggled()
    onToggled: {
        if (PowerProfiles.powerProfile === "power-saver") {
            PowerProfiles.setPowerProfile("balanced");
        } else if (PowerProfiles.powerProfile === "balanced") {
            PowerProfiles.setPowerProfile("performance");
        } else {
            PowerProfiles.setPowerProfile("power-saver");
        }
    }

    // Expanded view support
    property bool hasExpandedView: true
    property int expandedHeight: 320
    property Component expandedComponent: Component {
        Item {
            id: expandedRoot
            implicitHeight: contentLayout.implicitHeight

            ColumnLayout {
                id: contentLayout
                anchors.fill: parent
                spacing: 16

                // Header (no switch toggle)
                ExpandedHeader {
                    Layout.fillWidth: true
                    toggle: root
                }

                // Profile list
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Power Saver
                    Rectangle {
                        Layout.fillWidth: true
                        height: 72
                        radius: 8
                        color: PowerProfiles.powerProfile === "power-saver"
                            ? Qt.rgba(0.2, 0.5, 1.0, 0.15)
                            : (saverMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        Behavior on color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: PowerProfiles.powerProfile === "power-saver"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 0.3)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(20, 20)
                                    source: Icons.icon("power-profile-power-saver")
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "Power Saver"
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                Text {
                                    text: "Reduce performance to extend battery life"
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            // Selected indicator
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                border.width: 2
                                border.color: PowerProfiles.powerProfile === "power-saver"
                                    ? Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    : Qt.rgba(1, 1, 1, 0.3)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    visible: PowerProfiles.powerProfile === "power-saver"
                                    scale: PowerProfiles.powerProfile === "power-saver" ? 1.0 : 0.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        MouseArea {
                            id: saverMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfiles.setPowerProfile("power-saver")
                        }
                    }

                    // Balanced
                    Rectangle {
                        Layout.fillWidth: true
                        height: 72
                        radius: 8
                        color: PowerProfiles.powerProfile === "balanced"
                            ? Qt.rgba(0.2, 0.5, 1.0, 0.15)
                            : (balancedMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        Behavior on color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: PowerProfiles.powerProfile === "balanced"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 0.3)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(20, 20)
                                    source: Icons.icon("power-profile-balanced")
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "Balanced"
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                Text {
                                    text: "Standard performance with optimized battery usage"
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            // Selected indicator
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                border.width: 2
                                border.color: PowerProfiles.powerProfile === "balanced"
                                    ? Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    : Qt.rgba(1, 1, 1, 0.3)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    visible: PowerProfiles.powerProfile === "balanced"
                                    scale: PowerProfiles.powerProfile === "balanced" ? 1.0 : 0.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        MouseArea {
                            id: balancedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfiles.setPowerProfile("balanced")
                        }
                    }

                    // Performance
                    Rectangle {
                        Layout.fillWidth: true
                        height: 72
                        radius: 8
                        color: PowerProfiles.powerProfile === "performance"
                            ? Qt.rgba(0.2, 0.5, 1.0, 0.15)
                            : (perfMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        Behavior on color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: PowerProfiles.powerProfile === "performance"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 0.3)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(20, 20)
                                    source: Icons.icon("power-profile-performance")
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: "Performance"
                                    color: "white"
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                                Text {
                                    text: "Maximum performance at the cost of battery life"
                                    color: Qt.rgba(1, 1, 1, 0.5)
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            // Selected indicator
                            Rectangle {
                                width: 22; height: 22; radius: 11
                                color: "transparent"
                                border.width: 2
                                border.color: PowerProfiles.powerProfile === "performance"
                                    ? Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    : Qt.rgba(1, 1, 1, 0.3)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: Wallpapers.accentColor || Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    visible: PowerProfiles.powerProfile === "performance"
                                    scale: PowerProfiles.powerProfile === "performance" ? 1.0 : 0.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        MouseArea {
                            id: perfMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfiles.setPowerProfile("performance")
                        }
                    }
                }
            }
        }
    }
}
