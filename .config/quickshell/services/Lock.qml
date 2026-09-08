pragma Singleton
import Quickshell
import Quickshell.Wayland
import QtQuick

// Lock singleton — owns the screen lock state.
// The WlSessionLock lives in shell.qml (which has import "components").
// Consumers call Lock.lock() / Lock.unlock() / Lock.toggle() / read Lock.isLocked.
QtObject {
    id: lockService

    property bool isLocked: false

    function lock() {
        isLocked = true;
    }

    function unlock() {
        isLocked = false;
    }

    function toggle() {
        if (isLocked) unlock();
        else lock();
    }
}
