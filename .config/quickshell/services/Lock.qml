pragma Singleton
import Quickshell
import Quickshell.Wayland
import QtQuick

// Lock singleton — owns the screen lock state and exposes lock/unlock.
// The WlSessionLock + Lockscreen surface lives here. Consumers call
// Lock.lock() / Lock.unlock() / Lock.toggle() / read Lock.isLocked.
QtObject {
    id: lockService

    property bool isLocked: false

    WlSessionLock {
        id: sessionLock
        locked: lockService.isLocked
        surface: Lockscreen {}
    }

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
