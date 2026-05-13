import QtQuick
import QtQuick.Layouts
import ".."

// PowerProfileToggle.qml — Power Profiles toggle (data-only, styled by the shell).

Item {
    id: root
    property bool isControlWidget: true
    property bool isSimpleToggle: true
    property string toggleName: "Power Profile"
    property string subtitleText: {
        if (shellRoot.powerProfile === "power-saver") return "Power Saver";
        if (shellRoot.powerProfile === "performance") return "Performance";
        return "Balanced";
    }
    property string iconSource: shellRoot.icon("power-profile-" + shellRoot.powerProfile)
    property bool isActive: true
    property color activeColor: Qt.rgba(0.2, 0.5, 1.0, 1.0)
    
    signal toggled()
    onToggled: {
        if (shellRoot.powerProfile === "power-saver") {
            shellRoot.setPowerProfile("balanced");
        } else if (shellRoot.powerProfile === "balanced") {
            shellRoot.setPowerProfile("performance");
        } else {
            shellRoot.setPowerProfile("power-saver");
        }
    }

    // Expanded view support
    property bool hasExpandedView: true
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
                        radius: 16
                        color: shellRoot.powerProfile === "power-saver"
                            ? Qt.rgba(0.2, 0.5, 1.0, 0.15)
                            : (saverMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        border.width: shellRoot.powerProfile === "power-saver" ? 2 : 0
                        border.color: Qt.rgba(0.2, 0.5, 1.0, 0.6)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.width { NumberAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: shellRoot.powerProfile === "power-saver"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 0.3)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(20, 20)
                                    source: shellRoot.icon("power-profile-power-saver")
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
                                border.color: shellRoot.powerProfile === "power-saver"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    : Qt.rgba(1, 1, 1, 0.3)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    visible: shellRoot.powerProfile === "power-saver"
                                    scale: shellRoot.powerProfile === "power-saver" ? 1.0 : 0.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        MouseArea {
                            id: saverMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shellRoot.setPowerProfile("power-saver")
                        }
                    }

                    // Balanced
                    Rectangle {
                        Layout.fillWidth: true
                        height: 72
                        radius: 16
                        color: shellRoot.powerProfile === "balanced"
                            ? Qt.rgba(0.2, 0.5, 1.0, 0.15)
                            : (balancedMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        border.width: shellRoot.powerProfile === "balanced" ? 2 : 0
                        border.color: Qt.rgba(0.2, 0.5, 1.0, 0.6)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.width { NumberAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: shellRoot.powerProfile === "balanced"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 0.3)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(20, 20)
                                    source: shellRoot.icon("power-profile-balanced")
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
                                border.color: shellRoot.powerProfile === "balanced"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    : Qt.rgba(1, 1, 1, 0.3)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    visible: shellRoot.powerProfile === "balanced"
                                    scale: shellRoot.powerProfile === "balanced" ? 1.0 : 0.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        MouseArea {
                            id: balancedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shellRoot.setPowerProfile("balanced")
                        }
                    }

                    // Performance
                    Rectangle {
                        Layout.fillWidth: true
                        height: 72
                        radius: 16
                        color: shellRoot.powerProfile === "performance"
                            ? Qt.rgba(0.2, 0.5, 1.0, 0.15)
                            : (perfMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                        border.width: shellRoot.powerProfile === "performance" ? 2 : 0
                        border.color: Qt.rgba(0.2, 0.5, 1.0, 0.6)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.width { NumberAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14

                            Rectangle {
                                width: 40; height: 40; radius: 20
                                color: shellRoot.powerProfile === "performance"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 0.3)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Image {
                                    anchors.centerIn: parent
                                    sourceSize: Qt.size(20, 20)
                                    source: shellRoot.icon("power-profile-performance")
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
                                border.color: shellRoot.powerProfile === "performance"
                                    ? Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    : Qt.rgba(1, 1, 1, 0.3)
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 12; height: 12; radius: 6
                                    color: Qt.rgba(0.2, 0.5, 1.0, 1.0)
                                    visible: shellRoot.powerProfile === "performance"
                                    scale: shellRoot.powerProfile === "performance" ? 1.0 : 0.0
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                }
                            }
                        }

                        MouseArea {
                            id: perfMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shellRoot.setPowerProfile("performance")
                        }
                    }
                }
            }
        }
    }
}
