#!/usr/bin/env bash
set -euo pipefail

# --- Base build + Qt Quick runtime ----------------------------------------
sudo apt update
sudo apt install -y \
  g++ \
  git \
  ninja-build \
  cmake \
  pkg-config \
  qt6-base-dev \
  qt6-base-private-dev \
  qt6-declarative-dev \
  qml6-module-qtquick \
  qml6-module-qtquick-controls \
  qml6-module-qtquick-templates \
  qml6-module-qtquick-layouts \
  qml6-module-qtquick-window \
  qml6-module-qtqml-workerscript

# Optional: Qt WebSockets enables MQTT-over-WebSockets in the qtmqtt build.
# Without it qtmqtt still builds, just without that transport.
sudo apt install -y qt6-websockets-dev || true

# --- MQTT integration (Milestone 4) ---------------------------------------
# Debian/Raspberry Pi OS does not ship the Qt MQTT add-on in its repos
# (no `qt6-mqtt-dev`).  We first try the package in case a backport exists,
# and otherwise build the matching `qtmqtt` source release against the
# system Qt installation.

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

  # Sanity check that the Qt private headers are reachable. qtmqtt pulls in
  # Qt6::CorePrivate, and without qt6-base-private-dev the CMake configure
  # step fails with a confusing "Qt::CorePrivate includes non-existent path"
  # error.
  if ! find /usr/include -path '*/qt6/QtCore/*/QtCore/private' \
                         -print -quit 2>/dev/null | grep -q .; then
    echo "Qt private headers not found - install qt6-base-private-dev first:" >&2
    echo "  sudo apt install qt6-base-private-dev" >&2
    return 1
  fi

  echo "Building qtmqtt v${qt_version} from source to match the system Qt installation..."

  local workdir
  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' RETURN

  if ! git clone --depth 1 --branch "v${qt_version}" \
        https://code.qt.io/qt/qtmqtt.git "${workdir}/qtmqtt"; then
    echo "Could not clone qtmqtt v${qt_version} (tag may not exist)." >&2
    echo "You can list available tags with:" >&2
    echo "  git ls-remote --tags https://code.qt.io/qt/qtmqtt.git" >&2
    return 1
  fi

  if ! cmake -S "${workdir}/qtmqtt" -B "${workdir}/qtmqtt/build" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release; then
    echo "qtmqtt CMake configure failed - see errors above." >&2
    return 1
  fi

  if ! cmake --build "${workdir}/qtmqtt/build"; then
    echo "qtmqtt build failed - see errors above." >&2
    return 1
  fi

  # Verify the shared library was actually produced before letting the
  # install step ship a half-broken Qt6MqttConfig.cmake to the system.
  if [ -z "$(find "${workdir}/qtmqtt/build" -name 'libQt6Mqtt.so*' -print -quit)" ]; then
    echo "qtmqtt build did not produce libQt6Mqtt.so - refusing to install." >&2
    return 1
  fi

  if ! sudo cmake --install "${workdir}/qtmqtt/build"; then
    echo "qtmqtt install failed - see errors above." >&2
    return 1
  fi
}

# A previous failed run may have written a Qt6MqttConfig.cmake that points
# at a missing .so. Clean those leftovers up so the next CMake configure of
# HomeUI either picks up a freshly-built qtmqtt or falls back cleanly to
# 'MQTT disabled'.
cleanup_broken_qtmqtt_install() {
  local cfg_dir
  for cfg_dir in /usr/lib/aarch64-linux-gnu/cmake/Qt6Mqtt /usr/lib/*/cmake/Qt6Mqtt; do
    [ -d "${cfg_dir}" ] || continue
    if [ -z "$(find /usr/lib -name 'libQt6Mqtt.so*' -print -quit 2>/dev/null)" ]; then
      echo "Removing broken Qt6Mqtt install fragments under ${cfg_dir} (no matching libQt6Mqtt.so)."
      sudo rm -rf "${cfg_dir}" \
                  /usr/include/aarch64-linux-gnu/qt6/QtMqtt \
                  /usr/include/qt6/QtMqtt \
                  /usr/lib/aarch64-linux-gnu/metatypes/qt6mqtt_release_metatypes.json
    fi
  done
}

if sudo apt install -y qt6-mqtt-dev 2>/dev/null; then
  echo "Installed qt6-mqtt-dev from apt."
else
  echo "qt6-mqtt-dev not in apt repos - falling back to source build."
  cleanup_broken_qtmqtt_install
  if install_qtmqtt_from_source; then
    echo "qtmqtt built and installed - MQTT integration will be available."
  else
    echo "WARNING: qtmqtt could not be installed - MQTT integration will be disabled at build time." >&2
    cleanup_broken_qtmqtt_install
  fi
fi

echo "HomeUI Raspberry Pi build dependencies are installed."
