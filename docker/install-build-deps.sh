#!/usr/bin/env bash
# Install HomeUI build dependencies inside the Pi builder image (no sudo).
set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
  g++ \
  git \
  ninja-build \
  cmake \
  pkg-config \
  file \
  qt6-base-dev \
  qt6-base-private-dev \
  qt6-declarative-dev \
  qml6-module-qtquick \
  qml6-module-qtquick-controls \
  qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts \
  qml6-module-qtquick-window \
  qml6-module-qtqml-workerscript

apt-get install -y --no-install-recommends qt6-websockets-dev || true

install_qtmqtt_from_source() {
  local qt_version
  if command -v qmake6 >/dev/null 2>&1; then
    qt_version="$(qmake6 -query QT_VERSION 2>/dev/null || true)"
  fi
  if [ -z "${qt_version:-}" ]; then
    qt_version="$(dpkg-query -W -f='${Version}\n' qt6-base-dev 2>/dev/null | sed 's/+.*//;s/-.*//' || true)"
  fi
  if [ -z "${qt_version:-}" ]; then
    echo "Could not determine installed Qt 6 version - skipping qtmqtt build." >&2
    return 1
  fi

  if ! find /usr/include -path '*/qt6/QtCore/*/QtCore/private' \
                         -print -quit 2>/dev/null | grep -q .; then
    echo "Qt private headers not found." >&2
    return 1
  fi

  echo "Building qtmqtt v${qt_version} from source..."

  local workdir
  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' RETURN

  if ! git clone --depth 1 --branch "v${qt_version}" \
        https://code.qt.io/qt/qtmqtt.git "${workdir}/qtmqtt"; then
    echo "Could not clone qtmqtt v${qt_version}." >&2
    return 1
  fi

  cmake -S "${workdir}/qtmqtt" -B "${workdir}/qtmqtt/build" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build "${workdir}/qtmqtt/build"

  if [ -z "$(find "${workdir}/qtmqtt/build" -name 'libQt6Mqtt.so*' -print -quit)" ]; then
    echo "qtmqtt build did not produce libQt6Mqtt.so." >&2
    return 1
  fi

  cmake --install "${workdir}/qtmqtt/build"
}

if apt-get install -y --no-install-recommends qt6-mqtt-dev 2>/dev/null; then
  echo "Installed qt6-mqtt-dev from apt."
else
  echo "qt6-mqtt-dev not in apt - building qtmqtt from source."
  install_qtmqtt_from_source || echo "WARNING: qtmqtt unavailable; MQTT will be disabled at build time." >&2
fi

rm -rf /var/lib/apt/lists/*
