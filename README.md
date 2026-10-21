# DMS Plugins & Custom Registry

Custom plugins and official-compatible plugin registry for [Dux Shell (DMS)](https://github.com/duxlabs-dev/dux-shell).

## Plugins Included

| Plugin | Type | Description |
|---|---|---|
| **[RemminaLauncher](./RemminaLauncher)** | Launcher | Search and launch Remmina connection profiles directly from DMS launcher. |
| **[PeripheralsBattery](./PeripheralsBattery)** | Widget | Peripheral battery monitor with RegEx device categorization and bar pill display. |
| **[NbfcControl](./NbfcControl)** | Widget / CC | Fan speed monitor & controller via `nbfc-linux` with bar pill, Control Center tile, and OSD. |
| **[starshipWeather](./starshipWeather)** | Daemon | Background IPC daemon exposing current weather status string formatted for Starship prompt. |

## Adding This Registry to DMS

### Via DMS GUI
1. Open DMS Settings (`Mod + Comma`).
2. Navigate to **Plugins** -> **Manage** tab.
3. Under **Registries**, enter:
   - **Name:** `dms-plugins`
   - **URL:** `https://github.com/Angerion/dms-plugins.git`
4. Click **Add**.

### Via DMS CLI
```bash
dms registry add dms-plugins https://github.com/Angerion/dms-plugins.git
```

To list registered sources:
```bash
dms registry list
```

## Installing Plugins
Once the registry is added, plugins appear in the DMS Plugin Browser, or can be installed via CLI:
```bash
dms plugins install remminaLauncher
dms plugins install peripheralsBattery
dms plugins install nbfcControl
dms plugins install starshipWeather
```
