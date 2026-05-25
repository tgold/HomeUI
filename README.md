# HomeUI

Native OpenHAB touchscreen dashboard prototype for Raspberry Pi wall panels.

## Milestone 1 prototype

This repository currently contains the Milestone 1 shell:

- Qt 6/QML native application scaffold.
- Fullscreen 1280x800 touchscreen-oriented dashboard.
- Dark HABPanel-inspired visual style.
- Three horizontally swipeable pages:
  - Ground-floor overview.
  - Climate overview.
  - Energy and security overview.
- Static mock panels for rooms, lights, rollers, energy, operating modes, and camera placeholders.

The prototype does not connect to OpenHAB or MQTT yet. Those integrations are planned for later milestones.

## Project structure

```text
CMakeLists.txt
src/
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
./build-gcc/homeui
```

The app opens fullscreen by default for kiosk-style touchscreen use.

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
