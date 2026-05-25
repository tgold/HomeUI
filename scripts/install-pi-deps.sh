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

echo "HomeUI Raspberry Pi build dependencies are installed."
