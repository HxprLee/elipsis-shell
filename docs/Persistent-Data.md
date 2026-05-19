# Persistent Data (Saving Configuration)

Custom toggles often have configuration state in their expanded view (e.g., dropdown selections, sliders) that needs to persist across shell restarts. Hence, a universal, file-backed JSON data store is provided for this purpose.

## API

Use the `shellRoot` global object to access the API:

- `shellRoot.getToggleSetting(toggleId: string, key: string, defaultValue: var): var`
- `shellRoot.setToggleSetting(toggleId: string, key: string, value: var)`

## Integration Pattern

To avoid race conditions on startup (the toggle loading before the JSON file is fully parsed), use the following pattern with `shellRoot.toggleDataLoaded`. Use a `_loading` flag to prevent re-saving while loading.

```qml
Item {
    id: root
    // ...

    property int mySettingIndex: 0
    property string toggleId: "MyCustomToggle"
    property bool _loading: false

    function loadSettings() {
        if (!shellRoot.toggleDataLoaded) return;
        _loading = true;
        mySettingIndex = shellRoot.getToggleSetting(root.toggleId, "mySettingIndex", mySettingIndex)
        _loading = false;
    }

    // 1. Wait for data to be loaded
    Connections {
        target: shellRoot
        function onToggleDataLoadedChanged() {
            if (shellRoot.toggleDataLoaded) root.loadSettings();
        }
    }

    // 2. Load saved value on creation (if already loaded)
    Component.onCompleted: {
        loadSettings();
    }

    // 3. Save when changed (only if not currently loading)
    onMySettingIndexChanged: {
        if (!_loading) shellRoot.setToggleSetting(root.toggleId, "mySettingIndex", mySettingIndex)
    }
}
```

All data is automatically serialized and saved to `config/toggle_data.json`.
