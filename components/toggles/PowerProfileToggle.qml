import QtQuick

// PowerProfileToggle.qml — Power Profiles toggle (data-only, styled by the shell).

Item {
    property bool isSimpleToggle: true
    property string titleText: "Power Profile"
    property string subtitleText: {
        if (shellRoot.powerProfile === "power-saver") return "Power Saver";
        if (shellRoot.powerProfile === "performance") return "Performance";
        return "Balanced";
    }
    property string iconSource: shellRoot.icon("power-profile-" + shellRoot.powerProfile)
    property bool isActive: true
    property color activeColor: {
        if (shellRoot.powerProfile === "power-saver") return Qt.rgba(0.2, 0.8, 0.2, 1.0);
        if (shellRoot.powerProfile === "performance") return Qt.rgba(1.0, 0.3, 0.2, 1.0);
        return Qt.rgba(0.2, 0.5, 1.0, 1.0);
    }
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
}
