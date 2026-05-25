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
docs/
  openhab-touch-ui-plan.md
```

## Build requirements

- CMake 3.21 or newer.
- Qt 6.4 or newer with the Quick module.
- Qt QML runtime modules for QtQuick, QtQuick.Controls, QtQuick.Templates, QtQuick.Layouts, QtQuick.Window, and QtQml.WorkerScript.
- A C++17 compiler.

On Raspberry Pi OS or another Debian-based system, install Qt 6 development packages through the distribution packages or the Qt online installer.

Example Debian/Ubuntu packages:

```sh
sudo apt install g++ cmake qt6-base-dev qt6-declarative-dev \
  qml6-module-qtquick qml6-module-qtquick-controls \
  qml6-module-qtquick-templates qml6-module-qtquick-layouts \
  qml6-module-qtquick-window qml6-module-qtqml-workerscript
```

## Build and run

```sh
cmake -S . -B build
cmake --build build
./build/homeui
```

The app opens fullscreen by default for kiosk-style touchscreen use.
