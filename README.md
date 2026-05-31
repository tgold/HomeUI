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
- Scheduled overnight screen-off: the panel turns the backlight off from 00:00 until 06:30 by default, then restores the active brightness.

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
  build-pi-docker.sh
  install-pi-deps.sh
  install-service.sh
docker/
  Dockerfile.pi-build
  install-build-deps.sh
  build-in-container.sh
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

### Cross-build for Raspberry Pi (Docker)

Build on your Mac or Linux workstation for **Debian 13 (trixie) arm64** without installing Qt locally. The builder image uses `debian:trixie` with the same apt Qt packages as your panel.

**Requirements:** Docker CLI + a container runtime. The first run builds the image and may take several minutes (Qt + optional qtmqtt compile).

**macOS Ventura 13 (and older):** Current Docker Desktop requires Sonoma 14+. Use [Colima](https://colima.run) instead:

```sh
brew install colima docker
colima start
docker version    # should show Client and Server
```

Then run `./scripts/build-pi-docker.sh` as usual. Alternatively, install an older Docker Desktop from the [release notes](https://docs.docker.com/desktop/release-notes/) (pick a build from when Ventura was still listed as supported).

**macOS Sonoma 14+:** `brew install --cask docker`, then open Docker Desktop from Applications.

```sh
./scripts/build-pi-docker.sh
```

Output: `build-pi-docker/homeui` (aarch64 ELF). Copy to the panel and replace `/usr/local/bin/homeui`, or run `sudo cmake --install` on the Pi after copying the build tree.

```sh
scp build-pi-docker/homeui pi@your-panel:/tmp/homeui
ssh pi@your-panel 'sudo install -m 755 /tmp/homeui /usr/local/bin/homeui'
```

Useful flags:

| Flag | Purpose |
|------|---------|
| `--image` | Build or refresh the `homeui-pi-builder` image only |
| `--rebuild-image` | Force a clean image rebuild (no cache) |
| `--shell` | Interactive shell inside the builder (debugging) |
| `--build-dir <dir>` | Custom output directory |

On Intel Macs / x86_64 Linux, Docker runs the arm64 image via QEMU (slower but correct). Apple Silicon runs arm64 natively. The Docker build disables QML ahead-of-time compilation (`HOMEUI_NO_QML_CACHEGEN`) because `g++` often crashes under QEMU on large generated files; the panel loads QML from the binary resources at runtime instead.

If the build still fails, retry with a single job: `HOMEUI_BUILD_JOBS=1 ./scripts/build-pi-docker.sh`

**Parallelism:** Docker builds default to **2 compile jobs** (`HOMEUI_BUILD_JOBS=2`) because `g++` often crashes under QEMU on Intel Macs. Ninja still looks mostly sequential in the log (one `[n/72]` line per finished step). To use more cores:

```sh
HOMEUI_BUILD_JOBS=4 ./scripts/build-pi-docker.sh
```

Give Colima enough CPUs/RAM, then restart it:

```sh
colima stop
colima start --cpu 4 --memory 8
```

On **Intel Mac + arm64 image**, extra jobs help only a little — QEMU emulation is the bottleneck. Fastest path: build natively on the panel (`./scripts/install-pi-deps.sh` + `build-gcc`). **Apple Silicon** can usually set `HOMEUI_BUILD_JOBS=$(sysctl -n hw.ncpu)`.

After changing CMake options, wipe the output dir once: `rm -rf build-pi-docker`.

The binary links against system Qt on the panel — deploy to **Debian 13 (trixie)** with the same `qt6-*` packages from `install-pi-deps.sh`.

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
