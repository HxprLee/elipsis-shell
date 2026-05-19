# IPC Reference

All IPC calls use the Quickshell IPC mechanism. Invoke them from the command line with:

```bash
qs ipc call  <target> <function> [args...]
```

### `lock` — Session Lock

Defined in [`shell.qml`](../shell.qml)

| Function   | Arguments | Description                      |
| ---------- | --------- | -------------------------------- |
| `toggle`   | —         | Toggle the lock screen           |
| `lock`     | —         | Lock the session                 |
| `unlock`   | —         | Unlock the session               |

```bash
qs ipc call lock lock
qs ipc call lock unlock
qs ipc call lock toggle
```

### `task_manager` — Task Switcher

Defined in [`components/TaskManager.qml`](../components/TaskManager.qml)

| Function | Arguments | Description                    |
| -------- | --------- | ------------------------------ |
| `toggle` | —         | Toggle the task switcher       |
| `open`   | —         | Open the task switcher         |
| `close`  | —         | Close the task switcher        |

```bash
qs ipc call task_manager toggle
qs ipc call task_manager open
qs ipc call task_manager close
```

### `appearance` — Visual Settings

Defined in [`shell.qml`](../shell.qml)

| Function             | Arguments          | Description                                          |
| -------------------- | ------------------ | ---------------------------------------------------- |
| `setPrecomputedBlur` | `enabled` (string) | Enable/disable static wallpaper blur. Accepts `"true"`, `"1"`, `"false"`, `"0"`. |

```bash
qs ipc call appearance setPrecomputedBlur true
qs ipc call appearance setPrecomputedBlur false
```

### `power` — Power Menu

Defined in [`shell.qml`](../shell.qml)

| Function | Arguments | Description                    |
| -------- | --------- | ------------------------------ |
| `show`   | —         | Open the power menu            |
| `hide`   | —         | Close the power menu           |
| `toggle` | —         | Toggle the power menu          |

```bash
qs ipc call power show
qs ipc call power hide
qs ipc call power toggle
```

### `quicksettings` — Quick Settings Panel

Defined in [`shell.qml`](../shell.qml)

| Function | Arguments | Description                    |
| -------- | --------- | ------------------------------ |
| `show`   | —         | Open the quick settings panel  |
| `hide`   | —         | Close the quick settings panel |
| `toggle` | —         | Toggle the quick settings panel|

```bash
qs ipc call quicksettings show
qs ipc call quicksettings hide
qs ipc call quicksettings toggle
```
