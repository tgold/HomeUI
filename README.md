# HomeUI

Native OpenHAB touchscreen dashboard prototype for Raspberry Pi wall panels.

## Current prototype

This repository currently contains the Milestone 6 production shell:

- Qt 6/QML native application scaffold.
- Fullscreen 1280x800 touchscreen-oriented dashboard.
- Dark HABPanel-inspired visual style.
- Horizontally swipeable, JSON-driven pages and panels.
- OpenHAB REST integration for initial item states and commands.
- OpenHAB event stream integration for live item state updates with auto-reconnect.
- MQTT integration with broker auto-reconnect, Last Will, and retained heartbeat status.
- MQTT-backed control tiles and a dedicated `mqtt` panel type for read-only topics.
- MQTT control plane on `home/panel/<panel-id>/{page,brightness,reload}` topics.
- Home-automation widget catalogue: switch, dimmer (slider), roller shutter (up/stop/down), thermostat (+/- setpoint), and scene push button tiles, addressable per control via `kind`.
- Built-in live camera tile: MJPEG (Synology Surveillance Station, axis, motion, etc.) decoded directly in QML via a small `MjpegView` C++ component; JPEG snapshot polling as a low-bandwidth fallback.
- Raspberry Pi production deployment: systemd user / system service templates, XDG autostart fallback, idle screen dimming with touch-wake, live `dashboard.json` reloading on disk changes, and a structured `--log-level` controllable journal log.

See `docs/deployment.md` for the production kiosk install guide.

## Project structure

```text
CMakeLists.txt
config/
  dashboard.json
src/
  DashboardConfig.cpp
  DashboardConfig.h
  MjpegView.cpp
  MjpegView.h
  MqttClient.cpp
  MqttClient.h
  OpenHabClient.cpp
  OpenHabClient.h
  ScreenIdleController.cpp
  ScreenIdleController.h
  main.cpp
qml/
  Main.qml
  components/
    CameraTile.qml
    ConfiguredPage.qml
    ConfiguredPanel.qml
    ControlsPanel.qml
    ControlTile.qml
    DimmerTile.qml
    EnergyPanel.qml
    Format.js
    MetricRow.qml
    ModePanel.qml
    MqttPanel.qml
    PageDots.qml
    RoomPanel.qml
    SceneTile.qml
    ShutterTile.qml
    StatusBar.qml
    ThermostatTile.qml
scripts/
  install-pi-deps.sh
  install-service.sh
packaging/
  autostart/homeui.desktop
  autostart/homeui-wayland.desktop
  desktop/homeui.desktop
  systemd/homeui.service
  systemd/homeui-system.service
docs/
  dashboard-config.md
  deployment.md
  openhab-touch-ui-plan.md
```

## Build requirements

- CMake 3.21 or newer.
- Qt 6.4 or newer with the Quick module.
- Qt QML runtime modules for QtQuick, QtQuick.Controls, QtQuick.Templates, QtQuick.Layouts, QtQuick.Window, and QtQml.WorkerScript.
- A C++17 compiler.

On Raspberry Pi OS or another Debian-based system, install Qt 6 development packages through the distribution packages or the Qt online installer.

For Raspberry Pi OS / Debian / Ubuntu, the easiest setup is:

```sh
./scripts/install-pi-deps.sh
```

## Build and run

```sh
cmake -S . -B build-gcc -DCMAKE_CXX_COMPILER=g++
cmake --build build-gcc
HOMEUI_OPENHAB_URL=http://openhabian:8080 ./build-gcc/homeui
```

The app opens fullscreen by default for kiosk-style touchscreen use.

## Dashboard configuration

The dashboard layout is loaded from JSON. By default the app looks for:

```text
./config/dashboard.json
../config/dashboard.json
/etc/homeui/dashboard.json
```

You can set a specific file with either:

```sh
HOMEUI_CONFIG=/path/to/dashboard.json ./build-gcc/homeui
./build-gcc/homeui --config /path/to/dashboard.json
```

See `docs/dashboard-config.md` for the schema and examples.

## OpenHAB connection

The app connects to OpenHAB through:

- `GET /rest/items` for initial item states.
- `POST /rest/items/{itemName}` for commands.
- `GET /rest/events?topics=openhab/items/*` for live Server-Sent Events updates.

Configuration options:

```sh
HOMEUI_OPENHAB_URL=http://openhabian:8080 ./build-gcc/homeui
HOMEUI_OPENHAB_URL=http://openhabian:8080 HOMEUI_OPENHAB_TOKEN=... ./build-gcc/homeui
./build-gcc/homeui --openhab-url http://openhabian:8080
./build-gcc/homeui --openhab-url http://openhabian:8080 --openhab-token ...
./build-gcc/homeui --no-openhab
./build-gcc/homeui --config ./config/dashboard.json
```

If no URL is provided, the app tries `http://openhab:8080`.

OpenHAB item mappings now live in the dashboard config, for example:

```json
{
  "type": "room",
  "title": "Wohnzimmer",
  "items": {
    "temperature": "Wohnzimmer_Temperatur",
    "light": "Wohnzimmer_Licht",
    "shutter": "Wohnzimmer_Rollo"
  }
}
```

Rename those item values to match your OpenHAB item names.

## MQTT connection

The app talks to an MQTT broker for two purposes:

- Publishing its own heartbeat / status (`home/panel/<id>/status`, retained, with a Last-Will marking the panel offline on disconnect).
- Subscribing to remote control topics (`home/panel/<id>/page/set`, `brightness/set`, `reload`) and any topics bound to dashboard widgets.

Configuration options:

```sh
HOMEUI_MQTT_BROKER=mqtt://openhabian:1883 ./build-gcc/homeui
HOMEUI_MQTT_BROKER=mqtt://openhabian:1883 \
  HOMEUI_MQTT_USERNAME=panel HOMEUI_MQTT_PASSWORD=secret \
  HOMEUI_MQTT_PANEL_ID=wallpanel-eg ./build-gcc/homeui

./build-gcc/homeui --mqtt-broker mqtt://openhabian:1883 \
  --mqtt-username panel --mqtt-password secret \
  --mqtt-panel-id wallpanel-eg --mqtt-client-id wallpanel-eg-1
./build-gcc/homeui --no-mqtt
```

`HOMEUI_BRIGHTNESS_PATH=/sys/class/backlight/10-0045/brightness` can pin the backlight device written to by `brightness/set`. Otherwise the app picks the first device under `/sys/class/backlight/`.

If the Qt MQTT module is not available at build time the MQTT integration is silently dropped (the `--mqtt-*` flags become no-ops).

Debian / Raspberry Pi OS does not ship the Qt MQTT add-on (`qt6-mqtt-dev`) in its repositories. `scripts/install-pi-deps.sh` therefore tries `apt install qt6-mqtt-dev` first and, if that fails, clones the matching `qtmqtt` release from `https://code.qt.io/qt/qtmqtt.git` (using the system Qt version) and builds & installs it system-wide via CMake. After running the script, delete any existing `build-gcc/` directory and reconfigure so CMake picks up the freshly installed `Qt6::Mqtt`.

## Troubleshooting Qt detection

If CMake reports that it cannot find `Qt6Config.cmake` or `qt6-config.cmake`, the Qt development package is missing or CMake cannot see it.

First run:

```sh
./scripts/install-pi-deps.sh
```

Then clean the failed configure directory and rerun CMake:

```sh
rm -rf build-gcc
cmake -S . -B build-gcc -DCMAKE_CXX_COMPILER=g++
```

If Qt was installed with the Qt online installer instead of apt packages, pass the Qt install prefix explicitly:

```sh
cmake -S . -B build-gcc -DCMAKE_CXX_COMPILER=g++ \
  -DCMAKE_PREFIX_PATH=/path/to/Qt/6.x/gcc_arm64
```
