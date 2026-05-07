# Elipsis Shell — IPC Reference

All IPC calls use the Quickshell IPC mechanism. Invoke them from the command line with:

```bash
qs-ipc <target> <function> [args...]
```

---

## `lock` — Session Lock

Defined in [`shell.qml`](shell.qml)

| Function   | Arguments | Description                      |
| ---------- | --------- | -------------------------------- |
| `toggle`   | —         | Toggle the lock screen           |
| `lock`     | —         | Lock the session                 |
| `unlock`   | —         | Unlock the session               |

```bash
qs-ipc lock lock
qs-ipc lock unlock
qs-ipc lock toggle
```

---

## `task_manager` — Task Switcher

Defined in [`components/TaskManager.qml`](components/TaskManager.qml)

| Function | Arguments | Description                    |
| -------- | --------- | ------------------------------ |
| `toggle` | —         | Toggle the task switcher       |
| `open`   | —         | Open the task switcher         |
| `close`  | —         | Close the task switcher        |

```bash
qs-ipc task_manager toggle
qs-ipc task_manager open
qs-ipc task_manager close
```

---

## `appearance` — Visual Settings

Defined in [`shell.qml`](shell.qml)

| Function             | Arguments          | Description                                          |
| -------------------- | ------------------ | ---------------------------------------------------- |
| `setPrecomputedBlur` | `enabled` (string) | Enable/disable pre-computed wallpaper blur. Accepts `"true"`, `"1"`, `"false"`, `"0"`. |

```bash
qs-ipc appearance setPrecomputedBlur true
qs-ipc appearance setPrecomputedBlur false
```

---

## `power` — Power Menu

Defined in [`shell.qml`](shell.qml)

| Function | Arguments | Description                    |
| -------- | --------- | ------------------------------ |
| `show`   | —         | Open the power menu            |
| `hide`   | —         | Close the power menu           |
| `toggle` | —         | Toggle the power menu          |

```bash
qs-ipc power show
qs-ipc power hide
qs-ipc power toggle
```
