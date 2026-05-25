# HomeUI

Native OpenHAB touchscreen dashboard prototype for Raspberry Pi wall panels.

## Current prototype

This repository currently contains the Milestone 2 shell:

- Qt 6/QML native application scaffold.
- Fullscreen 1280x800 touchscreen-oriented dashboard.
- Dark HABPanel-inspired visual style.
- Three horizontally swipeable pages:
  - Ground-floor overview.
  - Climate overview.
  - Energy and security overview.
- Static mock panels for rooms, lights, rollers, energy, operating modes, and camera placeholders.
- OpenHAB REST integration for initial item states and commands.
- OpenHAB event stream integration for live item state updates.

MQTT integration and fully configurable dashboard panels are planned for later milestones.

## Project structure

```text
CMakeLists.txt
src/
  OpenHabClient.cpp
  OpenHabClient.h
  main.cpp
qml/
  Main.qml
  components/
    CameraTile.qml
    ControlTile.qml
    EnergyPanel.qml
    MetricRow.qml
    ModePanel.qml
    PageDots.qml
    RoomPanel.qml
    StatusBar.qml
scripts/
  install-pi-deps.sh
docs/
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
```

If no URL is provided, the app tries `http://openhab:8080`.

The current milestone still uses static item mappings in `qml/Main.qml`, for example:

```qml
RoomPanel {
    openhab: openhabClient
    title: "Wohnzimmer"
    temperatureItem: "Wohnzimmer_Temperatur"
    lightItem: "Wohnzimmer_Licht"
    shutterItem: "Wohnzimmer_Rollo"
}
```

Rename those item properties to match your OpenHAB item names until the configurable dashboard milestone moves this into external config.

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
