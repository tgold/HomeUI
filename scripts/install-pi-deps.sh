#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install -y \
  g++ \
  cmake \
  qt6-base-dev \
  qt6-declarative-dev \
  qml6-module-qtquick \
  qml6-module-qtquick-controls \
  qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts \
  qml6-module-qtquick-window \
  qml6-module-qtqml-workerscript

# MQTT integration (Milestone 4). Optional - the build will skip MQTT support
# automatically if these packages are not available.
sudo apt install -y qt6-mqtt-dev || \
  echo "qt6-mqtt-dev not available - MQTT integration will be disabled at build time."

echo "HomeUI Raspberry Pi build dependencies are installed."
