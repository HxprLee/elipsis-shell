pragma Singleton
import Quickshell
import Quickshell.Services.Notifications as Notifs
import QtQuick

// Notifications singleton — wraps Notifs.NotificationServer and owns the
// dndActive flag. Consumers read Notifications.notificationList and call
// Notifications.dismiss / dismissByApp / clearAll / setDnd.
// A signal `notificationReceived(item)` is emitted for each new/updated
// notification so the global toast can react in shell.qml.

QtObject {
    id: notifications

    property var notificationList: []
    property bool dndActive: false

    signal notificationReceived(var item)

    Notifs.NotificationServer {
        id: notificationServer

        onNotification: (notification) => {
            let item = {
                id: notification.id,
                appName: notification.appName,
                appIcon: notification.appIcon ?? "",
                summary: notification.summary,
                body: notification.body,
                timeout: notification.expireTimeout,
                timestamp: Date.now()
            };
            console.log("Notification received: ", item.summary);
            let copy = notifications.notificationList.slice();
            let found = false;
            for (let i = 0; i < copy.length; i++) {
                if (copy[i].id === item.id) {
                    copy[i] = item;
                    found = true;
                    break;
                }
            }
            if (!found) copy.unshift(item);
            notifications.notificationList = copy;

            notifications.notificationReceived(item);
        }
    }

    function dismiss(nid) {
        notificationList = notificationList.filter(n => n.id !== nid);
    }

    function dismissByApp(appName) {
        notificationList = notificationList.filter(n => n.appName !== appName);
    }

    function clearAll() {
        notificationList = [];
    }

    function setDnd(active) {
        dndActive = active;
        ConfigStore.setToggleSetting("DndToggle", "active", active);
    }
}
